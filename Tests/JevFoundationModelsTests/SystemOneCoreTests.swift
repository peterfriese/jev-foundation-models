import Testing
import Foundation
import FoundationModels
import SystemOneCore

@Suite("SystemOneCore Unit & Pluggable Backend Tests")
struct SystemOneCoreTests {

    @Generable
    enum BugSeverity: String, Sendable {
        case critical
        case major
        case minor
    }

    @Generable
    struct BugReportDecision: Sendable {
        @Guide(description: "Is this bug security sensitive?")
        var isSecuritySensitive: Bool

        @Guide(description: "Severity level of this issue")
        var severity: BugSeverity

        @Guide(description: "Priority rating from 0 to 4", .range(0...4))
        var priority: Int
    }

    @Test("SystemOneRequest and SystemOneResponse round-trip encoding matches protocol specification")
    func testSystemOneDTORoundTrip() throws {
        let request = SystemOneRequest(
            state: "Database connection leaking memory on pool worker #4",
            model: "systemone-fast",
            questions: [
                "isSecurity": .noul(instructions: "Is this a security vulnerability?"),
                "severity": .choice(
                    instructions: "What is the severity?",
                    criteria: ["critical": "Immediate outage", "minor": "Cosmetic issue"]
                ),
                "priority": .score(
                    instructions: "Priority score",
                    criteria: ["P0", "P1", "P2"]
                )
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(request)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"type\":\"noul\""))
        #expect(json.contains("\"type\":\"choice\""))
        #expect(json.contains("\"type\":\"score\""))
        #expect(json.contains("\"model\":\"systemone-fast\""))

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SystemOneRequest.self, from: data)
        #expect(decoded == request)
    }

    @Test("MockSystemOneBackend enables pluggable execution with SystemOneLanguageModel")
    func testMockSystemOneBackendExecution() async throws {
        let mockBackend = MockSystemOneBackend { request in
            #expect(request.questions.count == 3)
            #expect(request.state.contains("Memory leak detected"))

            return SystemOneResponse(
                model: "systemone-mock-v1",
                answers: [
                    "isSecuritySensitive": SystemOneAnswer(
                        type: "noul",
                        noul: 0.92,
                        confidence: 0.84,
                        probabilities: ["true": 0.92, "false": 0.08]
                    ),
                    "severity": SystemOneAnswer(
                        type: "choice",
                        choice: "critical",
                        confidence: 0.96,
                        probabilities: ["critical": 0.96, "major": 0.03, "minor": 0.01]
                    ),
                    "priority": SystemOneAnswer(
                        type: "score",
                        score: 4.0,
                        confidence: 0.90
                    )
                ],
                usage: SystemOneUsage(inputTokens: 140, outputTokens: 12),
                serverDurationMs: 24.5
            )
        }

        let model = SystemOneLanguageModel(backend: mockBackend, modelID: "systemone-mock-v1")
        let session = LanguageModelSession(model: model)

        let response = try await session.respond(
            to: "Alert: Memory leak detected in auth service worker",
            generating: BugReportDecision.self
        )

        #expect(response.content.isSecuritySensitive == true)
        #expect(response.content.severity == .critical)
        #expect(response.content.priority == 4)
        #expect(response.probability(for: "isSecuritySensitive") == 0.92)
        #expect(response.confidence(for: "severity") == 0.96)
        #expect(response.serverDurationMs == 24.5)
        #expect(response.usage.input.totalTokenCount == 140)
    }

    @Test("AnySystemOneBackend wraps custom backend cleanly with Hashable conformance")
    func testAnySystemOneBackendWrapping() async throws {
        let backend = MockSystemOneBackend { req in
            SystemOneResponse(model: "test", answers: [:])
        }
        let anyBackend1 = AnySystemOneBackend(backend)
        let anyBackend2 = AnySystemOneBackend(backend)

        #expect(anyBackend1 != anyBackend2) // Different UUIDs
        #expect(anyBackend1 == anyBackend1)

        var set = Set<AnySystemOneBackend>()
        set.insert(anyBackend1)
        #expect(set.contains(anyBackend1))
    }
}
