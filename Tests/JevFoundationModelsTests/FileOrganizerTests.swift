import Testing
import Foundation
import FoundationModels
@testable import JevFoundationModels

// MARK: - Test Generable Types for File Organizer

@Generable
enum TestContentDomain: String, CaseIterable, Sendable {
    case finance = "finance"
    case engineering = "engineering"
    case legal = "legal"
    case documentation = "documentation"
    case personal = "personal"
}

@Generable
enum TestWorkflowStage: String, CaseIterable, Sendable {
    case actionRequired = "action_required"
    case reference = "reference"
    case archive = "archive"
}

@Generable
struct TestFileTriageDecision: Sendable {
    @Guide(description: "The primary semantic topic of the file")
    var domain: TestContentDomain

    @Guide(description: "Recommended workflow triage bucket based on immediate actionability")
    var workflowStage: TestWorkflowStage

    @Guide(description: "True if this file contains sensitive secrets, API keys, passwords, credentials, or private PII")
    var isSensitive: Bool

    @Guide(description: "Decision confidence rating from 0 (ambiguous/uncertain) to 3 (clear definitive match)", .range(0...3))
    var confidenceScore: Int
}

// MARK: - Test Dynamic Profile

enum TestStrategy: String, Sendable {
    case domain
    case workflow
}

extension SessionPropertyValues {
    @SessionPropertyEntry
    var testStrategy: TestStrategy = .domain

    @SessionPropertyEntry
    var testQuarantine: Bool = true
}

struct TestOrganizerProfile: LanguageModelSession.DynamicProfile, Sendable {
    @LanguageModelSession.SessionProperty(\.testStrategy) var strategy: TestStrategy
    @LanguageModelSession.SessionProperty(\.testQuarantine) var quarantine: Bool

    let model: JevLanguageModel

    var body: some LanguageModelSession.DynamicProfile {
        if strategy == .workflow {
            LanguageModelSession.Profile {
                Instructions("Workflow triage instructions: prioritize actionability and urgency.")
            }
            .model(model)
            .historyTransform { Self.isolateCurrentTurn($0) }
        } else {
            LanguageModelSession.Profile {
                Instructions("Domain categorization instructions: classify by semantic subject matter.")
            }
            .model(model)
            .historyTransform { Self.isolateCurrentTurn($0) }
        }
    }

    static func isolateCurrentTurn(_ entries: [Transcript.Entry]) -> [Transcript.Entry] {
        let instructions = entries.filter {
            if case .instructions = $0 { return true }
            return false
        }
        if let last = entries.last, case .prompt = last {
            return instructions + [last]
        }
        return entries
    }
}

// MARK: - Test Suite

@Suite("File Organizer & Dynamic Profile Tests")
struct FileOrganizerTests {

    // MARK: - Schema Translation

    @Test("FileTriageDecision schema translates to multi-primitive Jev questions")
    func testSchemaTranslation() throws {
        let translator = SchemaTranslator()
        let translation = try translator.translate(TestFileTriageDecision.generationSchema)

        #expect(translation.questions.count == 4)

        // 1. domain -> choice
        guard case .choice(let dInst, let dCrit) = translation.questions["domain"] else {
            Issue.record("Expected 'domain' to translate to .choice")
            return
        }
        #expect(dInst.contains("primary semantic topic"))
        #expect(dCrit.count == 5)

        // 2. workflowStage -> choice
        guard case .choice(let wInst, let wCrit) = translation.questions["workflowStage"] else {
            Issue.record("Expected 'workflowStage' to translate to .choice")
            return
        }
        #expect(wInst.contains("workflow triage bucket"))
        #expect(wCrit.count == 3)

        // 3. isSensitive -> noul
        guard case .noul(let sInst) = translation.questions["isSensitive"] else {
            Issue.record("Expected 'isSensitive' to translate to .noul")
            return
        }
        #expect(sInst.contains("sensitive secrets"))

        // 4. confidenceScore -> score (range 0...3)
        guard case .score(let cInst, let cCrit) = translation.questions["confidenceScore"] else {
            Issue.record("Expected 'confidenceScore' to translate to .score")
            return
        }
        #expect(cInst.contains("confidence rating"))
        #expect(cCrit.count == 4) // 0...3 has 4 levels
    }

    // MARK: - Dynamic Profile State Adaptation

    actor StateRecorder {
        var states: [String] = []
        func record(_ state: String) {
            states.append(state)
        }
    }

    @Test("Dynamic profile dynamically switches instructions when session properties change")
    func testDynamicProfileSwitching() async throws {
        let recorder = StateRecorder()

        let mockTransport = MockJevTransport { request in
            await recorder.record(request.state)
            return JevResponse(
                model: "jev-simulated",
                answers: [
                    "domain": JevAnswer(type: "choice", choice: "finance"),
                    "workflowStage": JevAnswer(type: "choice", choice: "action_required"),
                    "isSensitive": JevAnswer(type: "noul", noul: 0.01),
                    "confidenceScore": JevAnswer(type: "score", score: 3.0)
                ],
                usage: JevUsage(inputTokens: 100, outputTokens: 10)
            )
        }

        let model = JevLanguageModel(apiKey: "mock-key", transport: mockTransport)
        let profile = TestOrganizerProfile(model: model)
        let session = LanguageModelSession(profile: profile)

        // Turn 1: Default is domain
        session.properties.testStrategy = .domain
        _ = try await session.respond(to: "Invoice INV-001 for $5,000", generating: TestFileTriageDecision.self)

        var states = await recorder.states
        #expect(states.count == 1)
        #expect(states[0].contains("Domain categorization instructions"))

        // Turn 2: Switch to workflow
        session.properties.testStrategy = .workflow
        _ = try await session.respond(to: "Invoice INV-002 for $1,200", generating: TestFileTriageDecision.self)

        states = await recorder.states
        #expect(states.count == 2)
        #expect(states[1].contains("Workflow triage instructions"))
    }

    // MARK: - Turn Isolation via .historyTransform

    @Test("historyTransform isolates file evaluation turns while preserving instructions")
    func testHistoryIsolation() {
        let entries: [Transcript.Entry] = [
            .instructions(Transcript.Instructions(id: UUID().uuidString, segments: [.text(Transcript.TextSegment(content: "System Prompt"))], toolDefinitions: [])),
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "File 1"))])),
            .response(Transcript.Response(segments: [.text(Transcript.TextSegment(content: "Result 1"))])),
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "File 2"))]))
        ]

        let isolated = TestOrganizerProfile.isolateCurrentTurn(entries)

        #expect(isolated.count == 2)
        if case .instructions(let inst) = isolated[0], case .text(let t) = inst.segments.first {
            #expect(t.content == "System Prompt")
        } else {
            Issue.record("Expected instructions as first entry")
        }

        if case .prompt(let p) = isolated[1], case .text(let t) = p.segments.first {
            #expect(t.content == "File 2")
        } else {
            Issue.record("Expected File 2 prompt as second entry")
        }
    }

    // MARK: - Destination Routing Logic

    @Test("Destination path resolver prioritizes sensitive quarantine, then review queue, then strategy")
    func testDestinationPathResolution() {
        func resolveDestinationPath(
            filename: String,
            decision: TestFileTriageDecision,
            strategy: TestStrategy,
            quarantineSensitive: Bool
        ) -> String {
            if quarantineSensitive && decision.isSensitive {
                return "Quarantine_Vault/\(filename)"
            }
            if decision.confidenceScore < 2 {
                return "Review_Queue/\(filename)"
            }
            switch strategy {
            case .workflow:
                switch decision.workflowStage {
                case .actionRequired: return "Workflow/1_Action_Required/\(filename)"
                case .reference:      return "Workflow/2_Reference_Material/\(filename)"
                case .archive:        return "Workflow/3_Archive/\(filename)"
                }
            case .domain:
                switch decision.domain {
                case .finance:       return "Organized/Finance_and_Billing/\(filename)"
                case .engineering:   return "Organized/Engineering_and_Code/\(filename)"
                case .legal:         return "Organized/Legal_and_Contracts/\(filename)"
                case .documentation: return "Organized/Documentation/\(filename)"
                case .personal:      return "Organized/Personal_Notes/\(filename)"
                }
            }
        }

        // Case 1: Sensitive credentials file + quarantine enabled -> Quarantine_Vault/
        let sensitiveDecision = TestFileTriageDecision(
            domain: .engineering,
            workflowStage: .actionRequired,
            isSensitive: true,
            confidenceScore: 3
        )
        let quarantinedPath = resolveDestinationPath(
            filename: "secrets.env",
            decision: sensitiveDecision,
            strategy: .domain,
            quarantineSensitive: true
        )
        #expect(quarantinedPath == "Quarantine_Vault/secrets.env")

        // Case 2: Sensitive file but quarantine disabled -> Normal domain path
        let unquarantinedPath = resolveDestinationPath(
            filename: "secrets.env",
            decision: sensitiveDecision,
            strategy: .domain,
            quarantineSensitive: false
        )
        #expect(unquarantinedPath == "Organized/Engineering_and_Code/secrets.env")

        // Case 3: Low confidence file (< 2) -> Review_Queue/
        let ambiguousDecision = TestFileTriageDecision(
            domain: .personal,
            workflowStage: .archive,
            isSensitive: false,
            confidenceScore: 1
        )
        let reviewPath = resolveDestinationPath(
            filename: "scratchpad.tmp",
            decision: ambiguousDecision,
            strategy: .domain,
            quarantineSensitive: true
        )
        #expect(reviewPath == "Review_Queue/scratchpad.tmp")

        // Case 4: High confidence file + domain strategy -> Domain folder
        let domainDecision = TestFileTriageDecision(
            domain: .finance,
            workflowStage: .actionRequired,
            isSensitive: false,
            confidenceScore: 3
        )
        let domainPath = resolveDestinationPath(
            filename: "invoice.txt",
            decision: domainDecision,
            strategy: .domain,
            quarantineSensitive: true
        )
        #expect(domainPath == "Organized/Finance_and_Billing/invoice.txt")

        // Case 5: High confidence file + workflow strategy -> Workflow folder
        let workflowPath = resolveDestinationPath(
            filename: "invoice.txt",
            decision: domainDecision,
            strategy: .workflow,
            quarantineSensitive: true
        )
        #expect(workflowPath == "Workflow/1_Action_Required/invoice.txt")
    }

    // MARK: - End-to-End Decoding

    @Test("serverDurationMs metadata propagates from JevResponse through executor to Response.serverDurationMs")
    func testServerDurationMetadataPropagation() async throws {
        let mockTransport = MockJevTransport { _ in
            JevResponse(
                model: "jev-1.13.0",
                answers: [
                    "domain": JevAnswer(type: "choice", choice: "finance"),
                    "workflowStage": JevAnswer(type: "choice", choice: "action_required"),
                    "isSensitive": JevAnswer(type: "noul", noul: 0.05),
                    "confidenceScore": JevAnswer(type: "score", score: 3.0)
                ],
                usage: JevUsage(inputTokens: 120, outputTokens: 15),
                serverDurationMs: 52.5
            )
        }

        let model = JevLanguageModel(apiKey: "mock-key", transport: mockTransport)
        let profile = TestOrganizerProfile(model: model)
        let session = LanguageModelSession(profile: profile)

        let response = try await session.respond(to: "Invoice for services", generating: TestFileTriageDecision.self)

        #expect(response.serverDurationMs == 52.5)
    }

    @Test("End-to-end: Session decodes multi-primitive triage decision with metadata")
    func testEndToEndTriageEvaluation() async throws {
        let mockTransport = MockJevTransport { request in
            #expect(request.questions.count == 4)
            #expect(request.state.contains("Silicon Valley Commercial Bank"))

            return JevResponse(
                model: "jev-1.13.0",
                answers: [
                    "domain": JevAnswer(
                        type: "choice",
                        choice: "finance",
                        confidence: 0.98,
                        probabilities: ["finance": 0.98, "legal": 0.02]
                    ),
                    "workflowStage": JevAnswer(
                        type: "choice",
                        choice: "action_required",
                        confidence: 0.95,
                        probabilities: ["action_required": 0.95, "archive": 0.05]
                    ),
                    "isSensitive": JevAnswer(
                        type: "noul",
                        noul: 0.02,
                        confidence: 0.96
                    ),
                    "confidenceScore": JevAnswer(
                        type: "score",
                        score: 3.0,
                        confidence: 0.94
                    )
                ],
                usage: JevUsage(inputTokens: 310, outputTokens: 18)
            )
        }

        let model = JevLanguageModel(apiKey: "mock-api-key", transport: mockTransport)
        let profile = TestOrganizerProfile(model: model)
        let session = LanguageModelSession(profile: profile)

        let prompt = """
        INVOICE: INV-2026-9041
        TOTAL DUE: $18,750.00 USD
        Wire Transfer: Silicon Valley Commercial Bank
        """

        let response = try await session.respond(to: prompt, generating: TestFileTriageDecision.self)

        #expect(response.content.domain == .finance)
        #expect(response.content.workflowStage == .actionRequired)
        #expect(response.content.isSensitive == false)
        #expect(response.content.confidenceScore == 3)

        #expect(response.probabilities["domain"]?["finance"] == 0.98)
        #expect(response.confidence(for: "domain") == 0.98)
        #expect(response.probability(for: "isSensitive") == 0.02)
        #expect(response.usage.input.totalTokenCount == 310)
    }
}
