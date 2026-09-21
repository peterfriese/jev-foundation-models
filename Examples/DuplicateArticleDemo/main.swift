import Foundation
import FoundationModels
import JevFoundationModels

printHeader()

// 1. Initialize Transport & Model
let apiKey = resolveAPIKey()
let model: JevLanguageModel

if let key = apiKey {
    print("🔑 Live TypeSafe AI API key detected. Evaluating against Jev cloud endpoint.")
    model = JevLanguageModel(apiKey: key)
} else {
    print("ℹ️  No TYPESAFE_API_KEY detected. Running in deterministic offline demonstration mode.")
    model = JevLanguageModel(apiKey: "offline-mock", transport: createOfflineMockTransport())
}

let deduplicator = ArticleDeduplicator(model: model, threshold: 0.60)

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
// Summary & Architecture Takeaway
// =============================================================================

print("""

================================================================================
  Summary: The Two-Layer Deduplication Pattern
================================================================================
  1. Layer 1 (Deterministic): Catches ~60-80% of duplicate saves at zero cost,
     zero tokens, and sub-millisecond execution.
  2. Layer 2 (Jev System One): Uses Apple Foundation Models (@Generable) to
     evaluate semantic substance in 50-100ms when headlines and URLs diverge.
  3. Calibrated Threshold: Fixed at 0.60 to maximize recall without sacrificing
     precision.
  4. The Escape Hatch: The AI warns, but the user always has the final say
     via "Save anyway".
================================================================================
""")
