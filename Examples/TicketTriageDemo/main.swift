import Foundation
import FoundationModels
import JevFoundationModels

// MARK: - 1. Define Your @Generable Decision Schema

@Generable
enum Department: String {
    case billing
    case engineering
    case sales
}

@Generable
struct TicketTriage {
    @Guide(description: "Is this customer inquiry urgent or blocking?")
    var isUrgent: Bool

    @Guide(description: "Which team should resolve this issue?")
    var department: Department

    @Guide(description: "Customer frustration score from 0 (calm) to 2 (hostile)", .range(0...2))
    var frustrationLevel: Int
}

// MARK: - 2. Setup Input & Environment

let apiKey = requireAPIKey()
let ticket = loadTicketText()
printDemoHeader(ticket: ticket)

// =============================================================================
// MARK: - 3. Native Apple Foundation Models + Jev Decision Call
// =============================================================================

let model = JevLanguageModel(apiKey: apiKey)
let session = LanguageModelSession(model: model)

let startTime = CFAbsoluteTimeGetCurrent()

let response = try await session.respond(
    to: ticket,
    generating: TicketTriage.self
)

let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

// =============================================================================
// MARK: - 4. Display Results & Decision Calibration
// =============================================================================

printDemoResults(response, durationMs: duration)
