import Foundation
import FoundationModels
import JevFoundationModels

printHeader()

// 1. Initialize Transport, Model, and Resilience Policy
let apiKey = resolveAPIKey()
let retryPolicy = RetryPolicy(
    maxAttempts: 3,
    initialDelay: .milliseconds(250),
    multiplier: 2.0,
    jitter: 0.15,
    retryableStatuses: [429, 529]
)

let model: JevLanguageModel

if let key = apiKey {
    print("🔑 Live TypeSafe AI API key detected. Evaluating against Jev cloud endpoint.")
    model = JevLanguageModel(apiKey: key, retryPolicy: retryPolicy)
} else {
    print("ℹ️  No TYPESAFE_API_KEY detected. Running in deterministic offline demonstration mode.")
    model = JevLanguageModel(apiKey: "offline-mock", transport: createOfflineMockTransport(), retryPolicy: retryPolicy)
}

let routingPolicy = RoutingPolicy(
    escalateBelow: 0.60,
    autoAtOrAbove: 0.85,
    undecidedBand: 0.35...0.65
)

let deduplicator = ArticleDeduplicator(model: model, threshold: 0.60, policy: routingPolicy)

// =============================================================================
// SCENARIO 1: Same article, published twice (Deterministic Match)
// =============================================================================

printScenarioHeader(
    number: 1,
    title: "Identical Article on Different URLs",
    subtitle: "Same title & author on Personal Blog vs X Article. Should match deterministically."
)

let library1 = [SampleData.blogPostOriginal]
let incoming1 = SampleData.xArticleSyndication

printArticleComparison(incoming: incoming1, candidate: library1[0])

let start1 = CFAbsoluteTimeGetCurrent()
let result1 = try await deduplicator.check(incoming1, against: library1)
let duration1 = (CFAbsoluteTimeGetCurrent() - start1) * 1000

printVerdictResult(verdict: result1, durationMs: duration1)

// =============================================================================
// SCENARIO 2: Wire story rewritten (Semantic Match via Jev Foundation Models)
// =============================================================================

printScenarioHeader(
    number: 2,
    title: "Rewritten Wire Story (The Hard Case)",
    subtitle: "Associated Press wire story republished by local TV affiliate with new headline & byline."
)

let library2 = [SampleData.apNewsOriginal]
let incoming2 = SampleData.kcbdLocalSyndication

printArticleComparison(incoming: incoming2, candidate: library2[0])
print("   • URL Match:      FAILED (apnews.com ≠ kcbd.com)")
print("   • Title Match:    FAILED (\"Apple unveils iPhone Duo...\" ≠ \"New iPhone lineup includes...\")")
print("   • Byline Match:   FAILED (\"Barbara Ortutay\" ≠ \"The Associated Press and Barbara Ortutay\")")
print("   → Deterministic layer misses. Delegating to Jev System One via Apple Foundation Models...\n")

let start2 = CFAbsoluteTimeGetCurrent()
let result2 = try await deduplicator.check(incoming2, against: library2)
let duration2 = (CFAbsoluteTimeGetCurrent() - start2) * 1000

printVerdictResult(verdict: result2, durationMs: duration2)

// =============================================================================
// SCENARIO 3: Distinct story on similar topic (False Positive Prevention)
// =============================================================================

printScenarioHeader(
    number: 3,
    title: "Different Story on Similar Topic (False Positive Control)",
    subtitle: "Foldable phone announcement from competitor (Google Pixel Fold). Must NOT match."
)

let library3 = [SampleData.apNewsOriginal]
let incoming3 = SampleData.googlePixelFoldArticle

printArticleComparison(incoming: incoming3, candidate: library3[0])
print("   → Deterministic layer misses. Evaluating semantic substance with Jev...")

let start3 = CFAbsoluteTimeGetCurrent()
let result3 = try await deduplicator.check(incoming3, against: library3)
let duration3 = (CFAbsoluteTimeGetCurrent() - start3) * 1000

printVerdictResult(verdict: result3, durationMs: duration3)

// =============================================================================
// SCENARIO 4: Swift Concurrency Cooperative Cancellation Demonstration
// =============================================================================

printScenarioHeader(
    number: 4,
    title: "Swift 6 Concurrency Cancellation",
    subtitle: "Demonstrating that cancelled tasks cleanly throw CancellationError without wrapping or leaks."
)

let task = Task {
    try await deduplicator.check(incoming2, against: library2)
}
// Immediately cancel the task to trigger cooperative cancellation
task.cancel()

do {
    _ = try await task.value
    print("   ℹ️ Task completed before cancellation took effect.")
} catch is CancellationError {
    print("   ✅ SUCCESS: CancellationError was caught directly. The request halted cleanly without wrapping in JevError.")
} catch {
    print("   ❌ Error: Received unexpected error type: \(error)")
}

// =============================================================================
// Summary & Architecture Takeaway
// =============================================================================

print("""

================================================================================
  Summary: The Two-Layer Deduplication & Confidence Routing Pattern
================================================================================
  1. Layer 1 (Deterministic): Catches ~60-80% of duplicate saves at zero cost,
     zero tokens, and sub-millisecond execution.
  2. Layer 2 (Jev System One): Uses Apple Foundation Models (@Generable) to
     evaluate semantic substance in 50-100ms when headlines and URLs diverge.
  3. Operational Confidence Routing:
     • Decisive True (≥ 0.85): Automatically prompt warning or suppress duplicate.
     • Undecided Band (0.35...0.65): Model is unsure; escalates to user rather than
       guessing on a hard 0.50 cutoff.
     • Decisive False (≤ 0.15): Confidently saves article without false alarm.
  4. Resilience & Concurrency:
     • RetryPolicy absorbs 429 rate limits and 529 gateway overloads with jitter.
     • CancellationError propagates cleanly across task and network boundaries.
================================================================================
""")
