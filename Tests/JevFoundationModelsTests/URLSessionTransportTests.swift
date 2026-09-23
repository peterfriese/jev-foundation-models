import Testing
import Foundation
@testable import JevFoundationModels

// MARK: - Mock URLProtocol for Offline Deterministic Testing

final class MockHTTPProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _responseQueue: [Result<(statusCode: Int, headers: [String: String], body: Data), any Error>] = []
    nonisolated(unsafe) private static var _requestCount: Int = 0

    static var requestCount: Int {
        lock.withLock { _requestCount }
    }

    static func reset() {
        lock.withLock {
            _responseQueue = []
            _requestCount = 0
        }
    }

    static func enqueue(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        lock.withLock {
            _responseQueue.append(.success((statusCode, headers, body)))
        }
    }

    static func enqueue(error: any Error) {
        lock.withLock {
            _responseQueue.append(.failure(error))
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.withLock {
            Self._requestCount += 1
        }

        let nextItem: Result<(statusCode: Int, headers: [String: String], body: Data), any Error>? = Self.lock.withLock {
            guard !Self._responseQueue.isEmpty else { return nil }
            return Self._responseQueue.removeFirst()
        }

        guard let next = nextItem else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        switch next {
        case .success(let item):
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://api.typesafe.ai/v1/systemone")!,
                statusCode: item.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: item.headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: item.body)
            client?.urlProtocolDidFinishLoading(self)

        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _delays: [Duration] = []

    func record(_ duration: Duration) {
        lock.withLock { _delays.append(duration) }
    }

    var delays: [Duration] {
        lock.withLock { _delays }
    }
}

// MARK: - Test Suite

@Suite("URLSessionTransport Resilience & Cancellation Tests", .serialized)
struct URLSessionTransportTests {

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockHTTPProtocol.self]
        return URLSession(configuration: config)
    }

    private let sampleSuccessJSON = """
    {
      "model": "jev-1.13.0",
      "answers": {
        "is_urgent": { "type": "noul", "noul": 0.95 }
      },
      "usage": { "input_tokens": 100, "output_tokens": 5 }
    }
    """.data(using: .utf8)!

    private let dummyRequest = JevRequest(
        state: "Test state",
        model: "jev-latest",
        questions: ["is_urgent": .noul(instructions: "Is this urgent?")]
    )

    private let endpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!

    @Test("429 Too Many Requests retries with backoff and eventual success is returned")
    func test429RetriesThenSucceeds() async throws {
        MockHTTPProtocol.reset()
        MockHTTPProtocol.enqueue(statusCode: 429, headers: ["Retry-After": "2"], body: Data("Rate limited".utf8))
        MockHTTPProtocol.enqueue(statusCode: 200, body: sampleSuccessJSON)

        let recorder = SleepRecorder()
        let transport = URLSessionTransport(
            session: makeSession(),
            timeoutInterval: 5,
            retryPolicy: RetryPolicy(maxAttempts: 3),
            sleep: { recorder.record($0) },
            randomness: { 0.5 },
            now: { Date() }
        )

        let response = try await transport.send(request: dummyRequest, apiKey: "key", endpoint: endpoint)

        #expect(response.model == "jev-1.13.0")
        #expect(MockHTTPProtocol.requestCount == 2)
        #expect(recorder.delays.count == 1)
        #expect(recorder.delays[0] == .seconds(2))
    }

    @Test("529 Site Overloaded exhausts maxAttempts and throws .overloaded")
    func test529ExhaustsMaxAttempts() async throws {
        MockHTTPProtocol.reset()
        MockHTTPProtocol.enqueue(statusCode: 529, body: Data("Overloaded".utf8))
        MockHTTPProtocol.enqueue(statusCode: 529, body: Data("Overloaded".utf8))
        MockHTTPProtocol.enqueue(statusCode: 529, body: Data("Overloaded".utf8))

        let recorder = SleepRecorder()
        let transport = URLSessionTransport(
            session: makeSession(),
            timeoutInterval: 5,
            retryPolicy: RetryPolicy(maxAttempts: 3, initialDelay: .milliseconds(100), jitter: 0),
            sleep: { recorder.record($0) },
            randomness: { 0.5 },
            now: { Date() }
        )

        await #expect(throws: JevError.overloaded) {
            try await transport.send(request: dummyRequest, apiKey: "key", endpoint: endpoint)
        }

        #expect(MockHTTPProtocol.requestCount == 3)
        // 3 attempts means 2 retry sleeps; no trailing sleep on final failure
        #expect(recorder.delays.count == 2)
    }

    @Test("401 Unauthorized is never retried and throws immediately")
    func test401NeverRetried() async throws {
        MockHTTPProtocol.reset()
        MockHTTPProtocol.enqueue(statusCode: 401, body: Data("Invalid API key".utf8))

        let transport = URLSessionTransport(
            session: makeSession(),
            timeoutInterval: 5,
            retryPolicy: RetryPolicy.default
        )

        await #expect(throws: JevError.unauthorized) {
            try await transport.send(request: dummyRequest, apiKey: "bad-key", endpoint: endpoint)
        }

        #expect(MockHTTPProtocol.requestCount == 1)
    }

    @Test("422 Unprocessable Content returns server body and is never retried")
    func test422NeverRetried() async throws {
        MockHTTPProtocol.reset()
        MockHTTPProtocol.enqueue(statusCode: 422, body: Data("State token count exceeded".utf8))

        let transport = URLSessionTransport(
            session: makeSession(),
            timeoutInterval: 5,
            retryPolicy: RetryPolicy.default
        )

        await #expect(throws: JevError.invalidRequest(body: "State token count exceeded")) {
            try await transport.send(request: dummyRequest, apiKey: "key", endpoint: endpoint)
        }

        #expect(MockHTTPProtocol.requestCount == 1)
    }

    @Test("Task cancellation is never wrapped in JevError and propagates cleanly")
    func testCancellationNeverWrapped() async throws {
        MockHTTPProtocol.reset()
        MockHTTPProtocol.enqueue(error: URLError(.cancelled))

        let transport = URLSessionTransport(
            session: makeSession(),
            timeoutInterval: 5,
            retryPolicy: RetryPolicy.default
        )

        do {
            _ = try await transport.send(request: dummyRequest, apiKey: "key", endpoint: endpoint)
            Issue.record("Expected CancellationError to be thrown")
        } catch is CancellationError {
            // Success: Clean CancellationError propagation
        } catch {
            Issue.record("Expected CancellationError, but received: \(error)")
        }
    }

    @Test("Task cancellation during sleep propagates CancellationError immediately")
    func testCancellationDuringSleep() async throws {
        MockHTTPProtocol.reset()
        MockHTTPProtocol.enqueue(statusCode: 429, headers: [:], body: Data())

        let transport = URLSessionTransport(
            session: makeSession(),
            timeoutInterval: 5,
            retryPolicy: RetryPolicy(maxAttempts: 3),
            sleep: { _ in throw CancellationError() },
            randomness: { 0.5 },
            now: { Date() }
        )

        do {
            _ = try await transport.send(request: dummyRequest, apiKey: "key", endpoint: endpoint)
            Issue.record("Expected CancellationError to be thrown")
        } catch is CancellationError {
            // Success: Clean CancellationError propagation
        } catch {
            Issue.record("Expected CancellationError, but received: \(error)")
        }
    }
}
