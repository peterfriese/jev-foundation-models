import Foundation
import FoundationModels
import JevFoundationModels

// MARK: - Environment & Key Resolution

func requireAPIKey() -> String {
    if let envVal = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"] {
        if !envVal.isEmpty { return envVal }
    } else {
        let envURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env")
        if let contents = try? String(contentsOf: envURL, encoding: .utf8) {
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
        }
    }

    print("""
    Error: No TypeSafe AI API key found.

    Please provide an API key using the TYPESAFE_API_KEY environment variable or a .env file.
    Example:
      export TYPESAFE_API_KEY="your-api-key"
      swift run ticket-triage-demo
    """)
    exit(1)
}

// MARK: - Input & Output Presentation

func loadTicketText() -> String {
    let customArgs = CommandLine.arguments.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    if !customArgs.isEmpty {
        return customArgs
    }
    return """
    Customer Ticket #8492:
    "I was double-charged on invoice #1042 this morning. The charge went through twice on our corporate Amex card, exceeding our department limit and pausing our production server deployment. Please refund the duplicate charge immediately!"
    """
}

func printDemoHeader(ticket: String) {
    print("==============================================================")
    print("  Jev for Apple Foundation Models — Ticket Triage Sample App  ")
    print("==============================================================\n")
    print("Input Context / State:")
    print("--------------------------------------------------------------")
    print(ticket)
    print("--------------------------------------------------------------\n")
    print("Evaluating decision with Jev System One model...")
}

func printDemoResults(
    _ response: LanguageModelSession.Response<TicketTriage>,
    durationMs: Double,
    policy: RoutingPolicy = .default
) {
    print("\nEvaluation Complete in \(String(format: "%.1f", durationMs))ms!")
    print("==============================================================")
    print("  Structured Decision Result (@Generable TicketTriage)")
    print("==============================================================")
    print("  • isUrgent:         \(response.content.isUrgent)")
    print("  • department:       \(response.content.department)")
    print("  • frustrationLevel: \(response.content.frustrationLevel) / 2")

    print("\nOperational Confidence Routing (Policy: auto ≥ \(formatPercentage(policy.autoAtOrAbove)), escalate < \(formatPercentage(policy.escalateBelow))):")
    print("--------------------------------------------------------------")

    // 1. Categorical Department Routing
    let deptDecision = response.decision(for: "department", policy: policy)
    let deptConf = response.confidence(for: "department")
    let confStr = deptConf.map { formatPercentage($0) } ?? "n/a"
    switch deptDecision {
    case .auto:
        print("  • Department Action:  [AUTO-ROUTE] ──► Route directly to \(response.content.department) inbox (Confidence: \(confStr))")
    case .confirm:
        print("  • Department Action:  [SUGGESTION] ──► Suggest \(response.content.department), prompt triage agent (Confidence: \(confStr))")
    case .escalate:
        print("  • Department Action:  [ESCALATE]   ──► Route to manual supervisor queue (Confidence: \(confStr))")
    }

    // 2. Boolean Noul Routing with Undecided Band
    let urgentJudgement = response.judgement(for: "isUrgent", policy: policy)
    let probStr = response.probability(for: "isUrgent").map { formatPercentage($0.value) } ?? "n/a"
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

    // 3. Rubric Score Inspection
    if let frustrationScore = response.scoreValue(for: "frustrationLevel") {
        let normStr = frustrationScore.normalized.map { String(format: "%.2f", $0) } ?? "n/a"
        print("  • Frustration Rubric: Weighted: \(String(format: "%.2f", frustrationScore.value)) | Rounded: Level \(frustrationScore.rounded) | Normalized: \(normStr)")
    }

    print("\nUsage & Telemetry:")
    print("--------------------------------------------------------------")
    print("  • Input tokens:     \(response.usage.input.totalTokenCount)")
    print("  • Output tokens:    \(response.usage.output.totalTokenCount)")

    for entry in response.transcriptEntries {
        if case .response(let r) = entry {
            printPrettyAnalytics(from: r.metadata)
        }
    }
    print("==============================================================\n")
}

// MARK: - Formatting Helpers

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
