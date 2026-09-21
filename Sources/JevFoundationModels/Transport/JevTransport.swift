import Foundation

/// A transport abstraction responsible for delivering requests to the TypeSafe AI Jev decision API.
public protocol JevTransport: Sendable {
    /// Dispatches a `JevRequest` and returns the deserialized `JevResponse`.
    func send(request: JevRequest, apiKey: String, endpoint: URL) async throws -> JevResponse
}

/// The default HTTP transport using Apple's native `URLSession`.
public struct URLSessionTransport: JevTransport, Hashable, Sendable {
    public let timeoutInterval: TimeInterval

    public init(timeoutInterval: TimeInterval = 30) {
        self.timeoutInterval = timeoutInterval
    }

    public func send(request: JevRequest, apiKey: String, endpoint: URL) async throws -> JevResponse {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = timeoutInterval

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw JevError.decodingError("Failed to encode JevRequest: \(error.localizedDescription)")
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        let session = URLSession(configuration: config)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw JevError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JevError.networkError("Invalid HTTP response received from server.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw JevError.apiError(statusCode: httpResponse.statusCode, message: body)
        }

        do {
            return try JSONDecoder().decode(JevResponse.self, from: data)
        } catch {
            throw JevError.decodingError("Failed to decode Jev response: \(error.localizedDescription)")
        }
    }
}

/// A mock transport enabling offline, deterministic automated testing without live API credentials.
public struct MockJevTransport: JevTransport, Hashable, Sendable {
    public let id: UUID
    private let handler: @Sendable (JevRequest) async throws -> JevResponse

    public init(
        id: UUID = UUID(),
        handler: @escaping @Sendable (JevRequest) async throws -> JevResponse
    ) {
        self.id = id
        self.handler = handler
    }

    public static func == (lhs: MockJevTransport, rhs: MockJevTransport) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public func send(request: JevRequest, apiKey: String, endpoint: URL) async throws -> JevResponse {
        try await handler(request)
    }
}

/// A type-erased `JevTransport` that conforms to `Hashable` and `Sendable`.
public struct AnyJevTransport: JevTransport, Hashable, Sendable {
    public let id: UUID
    private let _send: @Sendable (JevRequest, String, URL) async throws -> JevResponse

    public init(_ transport: some JevTransport, id: UUID = UUID()) {
        self.id = id
        self._send = { try await transport.send(request: $0, apiKey: $1, endpoint: $2) }
    }

    public init(id: UUID = UUID(), handler: @escaping @Sendable (JevRequest) async throws -> JevResponse) {
        self.id = id
        self._send = { req, _, _ in try await handler(req) }
    }

    public static func == (lhs: AnyJevTransport, rhs: AnyJevTransport) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public func send(request: JevRequest, apiKey: String, endpoint: URL) async throws -> JevResponse {
        try await _send(request, apiKey, endpoint)
    }
}
