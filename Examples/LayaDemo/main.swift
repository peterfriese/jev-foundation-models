import Foundation
import FoundationModels
import LayaFoundationModels

// MARK: - 1. Define Typed @Generable Schema

@Generable
enum SupportDepartment: String, Sendable {
    case billing
    case technical
    case sales
    case general
}

@Generable
struct CustomerInquiryTriage: Sendable {
    @Guide(description: "Is this inquiry urgent, mission-critical, or blocking?")
    var isUrgent: Bool

    @Guide(description: "Which specialized team should handle this request?")
    var department: SupportDepartment

    @Guide(description: "Customer frustration level from 0 (calm) to 2 (hostile)", .range(0...2))
    var frustrationLevel: Int
}

// MARK: - 2. Parse Command Line Arguments

let defaultInput = """
Customer Ticket #9102:
"Hi team, our enterprise subscription renewed today but our billing credit card was charged twice ($1,250 each). Our accounting team locked the card and our CI/CD deployment pipelines are blocked. Please refund the duplicate transaction immediately!"
"""

let stateText: String
if CommandLine.arguments.count > 1 {
    stateText = CommandLine.arguments.dropFirst().joined(separator: " ")
} else {
    stateText = defaultInput
}

// Check for custom endpoint via environment variable (default: http://127.0.0.1:8000/v1/systemone)
let endpoint: LayaEndpoint
if let envURL = ProcessInfo.processInfo.environment["LAYA_ENDPOINT"], let url = URL(string: envURL) {
    endpoint = .custom(url)
} else {
    endpoint = .localDefault
}

print("""
==============================================================
  System One Foundation Models — Local Laya Demo 🧠⚡️
==============================================================
Target Endpoint: \(endpoint.url.absoluteString)

Input Context / State:
--------------------------------------------------------------
\(stateText)
--------------------------------------------------------------
Evaluating decision with Laya System One model...
""")

// MARK: - 3. Connect via Apple Foundation Models Session

let model = LayaLanguageModel(endpoint: endpoint)
let session = LanguageModelSession(model: model)

let startTime = CFAbsoluteTimeGetCurrent()

do {
    let response = try await session.respond(
        to: stateText,
        generating: CustomerInquiryTriage.self
    )

    let durationMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
    let triage = response.content

    print("""

Evaluation Complete in \(String(format: "%.1f", durationMs))ms!
==============================================================
  Structured Decision Result (@Generable CustomerInquiryTriage)
==============================================================
  • isUrgent:         \(triage.isUrgent)
  • department:       \(triage.department)
  • frustrationLevel: \(triage.frustrationLevel) / 2
""")

    // MARK: - 4. Operational Confidence Routing

    let policy = RoutingPolicy(escalateBelow: 0.60, autoAtOrAbove: 0.85)
    print("Operational Confidence Routing (Policy: auto ≥ \(formatPercentage(policy.autoAtOrAbove)), escalate < \(formatPercentage(policy.escalateBelow))):")
    print("--------------------------------------------------------------")

    // Categorical Department Decision
    let deptDecision = response.decision(for: "department", policy: policy)
    let deptConf = response.confidence(for: "department")
    let confStr = deptConf.map(formatPercentage) ?? "n/a"
    switch deptDecision {
    case .auto:
        print("  • Department Action:  [AUTO-ROUTE] ──► Route directly to \(triage.department) inbox (Confidence: \(confStr))")
    case .confirm:
        print("  • Department Action:  [SUGGESTION] ──► Suggest \(triage.department), prompt triage agent (Confidence: \(confStr))")
    case .escalate:
        print("  • Department Action:  [ESCALATE]   ──► Route to manual supervisor queue (Confidence: \(confStr))")
    }

    // Boolean Noul Routing with Undecided Band
    let urgentJudgement = response.judgement(for: "isUrgent", policy: policy)
    let probStr = response.probability(for: "isUrgent").map(formatPercentage) ?? "n/a"
    switch urgentJudgement.decision {
    case .auto:
        if urgentJudgement.answer == true {
            print("  • Urgency Action:     [P0 CRITICAL] ──► Confident urgent; page on-call response team (Prob: \(probStr))")
        } else {
            print("  • Urgency Action:     [STANDARD SLA] ──► Confident routine; standard queue (Prob: \(probStr))")
        }
    case .confirm:
        print("  • Urgency Action:     [CONFIRM PRIORITY] ──► Leaning priority; prompt agent to confirm (Prob: \(probStr))")
    case .escalate:
        print("  • Urgency Action:     [UNDECIDED ESCALATE] ──► Model inside 0.35...0.65 band; manual triage (Prob: \(probStr))")
    }

    // Rubric Score Inspection
    if let frustrationScore = response.scoreValue(for: "frustrationLevel") {
        let normStr = frustrationScore.normalized.map { String(format: "%.2f", $0) } ?? "n/a"
        print("  • Frustration Rubric: Weighted: \(String(format: "%.2f", frustrationScore.value)) | Rounded: Level \(frustrationScore.rounded) | Normalized: \(normStr)")
    }

    // MARK: - 5. Telemetry & Analytics

    print("\nUsage & Telemetry:")
    print("--------------------------------------------------------------")
    print("  • Input tokens:       \(response.usage.input.totalTokenCount)")
    print("  • Output tokens:      \(response.usage.output.totalTokenCount)")
    if let serverMs = response.serverDurationMs {
        print(String(format: "  • Model Inference Time: %.1fms (Server forward pass)", serverMs))
    }
    if let transportMs = response.transportDurationMs {
        print(String(format: "  • Network Roundtrip:    %.1fms (HTTP transit + inference)", transportMs))
    }
    print(String(format: "  • Client Total Time:    %.1fms (Swift session wall time)", durationMs))

    for entry in response.transcriptEntries {
        if case .response(let r) = entry {
            printPrettyAnalytics(from: r.metadata)
        }
    }
    print("==============================================================\n")

} catch let error as SystemOneError {
    print("""

❌ System One Error:
   \(error.localizedDescription)

💡 Troubleshooting Tip:
   Make sure your local laya server is running on \(endpoint.url.absoluteString):
     laya-serve
""")
    exit(1)
} catch {
    print("""

❌ Connection Error:
   \(error.localizedDescription)

💡 Is laya-serve running?
   Start it in a terminal using:
     laya-serve
""")
    exit(1)
}

// MARK: - Helper Formatting Functions

func formatPercentage(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

func extractRawJSONString(from content: GeneratedContent) -> String {
    if let str = try? content.value(String.self) {
        return str
    }
    return content.jsonString
}

func printPrettyAnalytics(from metadata: [String: GeneratedContent]) {
    print("\nDecision Analytics & Calibration:")
    print("--------------------------------------------------------------")

    if let modelContent = metadata["model"] {
        let modelID = (try? modelContent.value(String.self)) ?? modelContent.jsonString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        print("  • Model:            \(modelID)")
    }

    if let confContent = metadata["confidence"] {
        let rawJSON = extractRawJSONString(from: confContent)
        if let confData = rawJSON.data(using: .utf8),
           let confDict = try? JSONSerialization.jsonObject(with: confData) as? [String: Double] {
            print("\n  Confidence Scores:")
            for key in confDict.keys.sorted() {
                let confVal = confDict[key] ?? 0.0
                let paddedKey = key.padding(toLength: 18, withPad: " ", startingAt: 0)
                print("    • \(paddedKey) \(formatPercentage(confVal))")
            }
        }
    }

    if let probsContent = metadata["probabilities"] {
        let rawJSON = extractRawJSONString(from: probsContent)
        if let probsData = rawJSON.data(using: .utf8),
           let probsDict = try? JSONSerialization.jsonObject(with: probsData) as? [String: [String: Double]] {
            print("\n  Calibrated Probabilities:")
            for key in probsDict.keys.sorted() {
                print("    • \(key):")
                let subDict = probsDict[key] ?? [:]
                for outcome in subDict.keys.sorted() {
                    let prob = subDict[outcome] ?? 0.0
                    let paddedOutcome = outcome.padding(toLength: 14, withPad: " ", startingAt: 0)
                    print("      - \(paddedOutcome) \(formatPercentage(prob))")
                }
            }
        }
    }
}
