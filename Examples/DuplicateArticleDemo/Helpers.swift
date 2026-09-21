import Foundation
import FoundationModels
import JevFoundationModels

// MARK: - Environment & Key Resolution

func resolveAPIKey() -> String? {
    if let envVal = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"], !envVal.isEmpty {
        return envVal
    }

    let envURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env")
    guard let contents = try? String(contentsOf: envURL, encoding: .utf8) else { return nil }

    for line in contents.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") || trimmed.isEmpty { continue }
        let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
        if parts.count == 2 && parts[0].trimmingCharacters(in: .whitespaces) == "TYPESAFE_API_KEY" {
            var val = parts[1].trimmingCharacters(in: .whitespaces)
            if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
                val = String(val.dropFirst().dropLast())
            }
            if !val.isEmpty { return val }
        }
    }
    return nil
}

/// Creates a simulated mock transport for offline demonstration when no live API key is configured.
func createOfflineMockTransport() -> MockJevTransport {
    MockJevTransport { request in
        // Determine whether incoming state matches the AP/KCBD wire story
        let state = request.state.lowercased()
        let isAPStoryDuplicate = state.contains("foldable version called duo") && state.contains("apple on wednesday unveiled")

        let noulValue: Double = isAPStoryDuplicate ? 0.93 : 0.01

        return JevResponse(
            model: "jev-offline-simulated",
            answers: [
                "isDuplicate": JevAnswer(
                    type: "noul",
                    noul: noulValue,
                    confidence: abs(noulValue - 0.5) * 2.0,
                    probabilities: ["true": noulValue, "false": max(0.0, 1.0 - noulValue)]
                )
            ],
            usage: JevUsage(inputTokens: 540, outputTokens: 22)
        )
    }
}

// MARK: - Console Output & Styling Helpers

func printHeader() {
    print("""
    ================================================================================
      Article Deduplication with Jev & Apple Foundation Models
      Two-Layer Architecture: Fast String Matching + System One Decision Model
    ================================================================================
    """)
}

func printScenarioHeader(number: Int, title: String, subtitle: String) {
    print("\n--------------------------------------------------------------------------------")
    print("▶ SCENARIO \(number): \(title)")
    print("  \(subtitle)")
    print("--------------------------------------------------------------------------------")
}

func printArticleComparison(incoming: Article, candidate: Article) {
    print("""
    +-------------+------------------------------------------------------------------+
    | Attribute   | Incoming Article                                                 |
    +-------------+------------------------------------------------------------------+
    | Title       | \(incoming.title.prefix(64))
    | Byline      | \(incoming.byline ?? "None")
    | URL         | \(incoming.url.absoluteString.prefix(64))
    +-------------+------------------------------------------------------------------+
    | Attribute   | Candidate in Library                                             |
    +-------------+------------------------------------------------------------------+
    | Title       | \(candidate.title.prefix(64))
    | Byline      | \(candidate.byline ?? "None")
    | URL         | \(candidate.url.absoluteString.prefix(64))
    +-------------+------------------------------------------------------------------+
    """)
}

func printVerdictResult(verdict: DeduplicationVerdict, durationMs: Double) {
    let durationString = String(format: "%.1f ms", durationMs)

    switch verdict {
    case .duplicate(let match):
        print("⚡️ RESULT: ⚠️  DUPLICATE DETECTED (Evaluated in \(durationString))")
        print("   • Match Layer: \(match.reason.description)")
        print("   • Candidate:   \"\(match.candidate.title)\"")

        switch match.reason {
        case .deterministic:
            print("   • Telemetry:   0 tokens consumed (Local deterministic check)")
        case .semantic(let prob, let thresh):
            print(String(format: "   • Calibration: Calibrated P(true) = %.2f ≥ %.2f threshold", prob, thresh))
        }

        print("\n   [UI Action: Displaying Warning with Escape Hatch]")
        print("   ┌──────────────────────────────────────────────────────────────┐")
        print("   │  ⚠️ You already saved a story with this content.             │")
        print("   │  Existing: \"\(match.candidate.title.prefix(44))...\"           │")
        print("   │                                                              │")
        print("   │  [Cancel]                    [Save anyway (Escape Hatch)]    │")
        print("   └──────────────────────────────────────────────────────────────┘")

    case .unique:
        print("⚡️ RESULT: ✅  UNIQUE ARTICLE (Evaluated in \(durationString))")
        print("   • No duplicate found in library.")
        print("   • Safe to persist directly into knowledge library.")
    }
}
