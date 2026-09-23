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
// MARK: - 3. Native Apple Foundation Models + Jev Resilience & Routing
// =============================================================================

// Configure resilient HTTP transport with backoff, jitter, and RFC 9110 Retry-After
let retryPolicy = RetryPolicy(
    maxAttempts: 3,
    initialDelay: .milliseconds(250),
    multiplier: 2.0,
    jitter: 0.15,
    retryableStatuses: [429, 529]
)

let model = JevLanguageModel(apiKey: apiKey, retryPolicy: retryPolicy)
let session = LanguageModelSession(model: model)

let startTime = CFAbsoluteTimeGetCurrent()

do {
    let response = try await session.respond(
        to: ticket,
        generating: TicketTriage.self
    )

    let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    // =============================================================================
    // MARK: - 4. Confidence & Noul Routing
    // =============================================================================

    let routingPolicy = RoutingPolicy(escalateBelow: 0.60, autoAtOrAbove: 0.85)

    printDemoResults(response, durationMs: duration, policy: routingPolicy)
} catch let error as JevError {
    print("\n❌ Decision Evaluation Failed with typed JevError:")
    print("   \(error.localizedDescription)")
    exit(1)
} catch {
    print("\n❌ Unexpected Error: \(error.localizedDescription)")
    exit(1)
}
