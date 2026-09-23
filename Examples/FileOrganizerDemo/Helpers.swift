import Foundation
import FoundationModels
import JevFoundationModels

// MARK: - API Key Resolution

/// Resolves the TypeSafe API key from the environment or `.env` file.
public func resolveAPIKey() -> String? {
    if let envVal = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"], !envVal.isEmpty {
        return envVal
    }

    let searchPaths = [
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env"),
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent().appendingPathComponent(".env")
    ]

    for envURL in searchPaths {
        guard let contents = try? String(contentsOf: envURL, encoding: .utf8) else { continue }
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
    return nil
}

// MARK: - Deterministic Offline Mock Transport

/// Generates calibrated Jev responses offline when no live `TYPESAFE_API_KEY` is present.
public func createOfflineMockTransport() -> MockJevTransport {
    MockJevTransport { request in
        let lower = request.state.lowercased()

        let domain: String
        let workflow: String
        let sensitiveProb: Double
        let confidenceScore: Double

        if lower.contains("aws_secret_access_key") || lower.contains("production_credentials.env") || lower.contains("stripe_secret_key") {
            domain = "engineering"
            workflow = "action_required"
            sensitiveProb = 0.99
            confidenceScore = 3.0
        } else if lower.contains("invoice:") || lower.contains("wire transfer instructions") || lower.contains("payment due") {
            domain = "finance"
            workflow = "action_required"
            sensitiveProb = 0.01
            confidenceScore = 3.0
        } else if lower.contains("master services agreement") || lower.contains("nondisclosure") || lower.contains("confidentiality & proprietary") {
            domain = "legal"
            workflow = "archive"
            sensitiveProb = 0.04
            confidenceScore = 3.0
        } else if lower.contains("tokenauthmiddleware") || lower.contains("swift 6 strict concurrency") {
            domain = "engineering"
            workflow = "reference"
            sensitiveProb = 0.01
            confidenceScore = 3.0
        } else if lower.contains("system architecture") || lower.contains("jev foundation models subsystem") {
            domain = "documentation"
            workflow = "reference"
            sensitiveProb = 0.01
            confidenceScore = 3.0
        } else if lower.contains("weekend to-do") || lower.contains("whole foods") {
            domain = "personal"
            workflow = "archive"
            sensitiveProb = 0.01
            confidenceScore = 3.0
        } else {
            // Ambiguous scratchpad
            domain = "personal"
            workflow = "archive"
            sensitiveProb = 0.12
            confidenceScore = 1.0 // Low confidence triggers Review_Queue
        }

        var domainProbs: [String: Double] = [domain: confidenceScore >= 2 ? 0.96 : 0.42]
        if domain != "personal" {
            domainProbs["personal"] = 0.04
        } else {
            domainProbs["documentation"] = 0.04
        }

        return JevResponse(
            model: "jev-offline-simulated",
            answers: [
                "domain": JevAnswer(
                    type: "choice",
                    choice: domain,
                    confidence: confidenceScore >= 2 ? 0.96 : 0.42,
                    probabilities: domainProbs
                ),
                "workflowStage": JevAnswer(
                    type: "choice",
                    choice: workflow,
                    confidence: confidenceScore >= 2 ? 0.95 : 0.38,
                    probabilities: [
                        workflow: confidenceScore >= 2 ? 0.95 : 0.38
                    ]
                ),
                "isSensitive": JevAnswer(
                    type: "noul",
                    noul: sensitiveProb,
                    confidence: abs(sensitiveProb - 0.5) * 2.0
                ),
                "confidenceScore": JevAnswer(
                    type: "score",
                    score: confidenceScore,
                    confidence: 0.90
                )
            ],
            usage: JevUsage(inputTokens: 240, outputTokens: 12)
        )
    }
}

// MARK: - Visual Tree and Table Formatters

public func printDemoBanner() {
    print("""
    ================================================================================
      Jev & Apple Foundation Models: Dynamic Profile Directory Organizer
      Declarative Session Profiles • System One Multitask Decisions • Zero-Cost Turn Isolation
    ================================================================================
    """)
}

public func printStrategyBanner(strategy: OrganizationStrategy, quarantine: Bool) {
    let modeTitle = strategy == .domain ? "Domain-Specific Categorization" : "Actionable Workflow Triaging"
    print("""

    ================================================================================
      ACTIVE DYNAMIC PROFILE: \(modeTitle.uppercased())
      • Strategy:            \(strategy.rawValue)
      • Sensitive Vault:     \(quarantine ? "ENABLED (Routes credentials to Quarantine_Vault/)" : "DISABLED")
      • Turn Isolation:      isolateCurrentTurn (.historyTransform active)
    ================================================================================
    """)
}

/// Prints an ASCII directory tree representing files and folders.
public func printDirectoryTree(title: String, paths: [String]) {
    print("\n📂 \(title):")

    // Group paths by top-level directory or root
    var tree: [String: [String]] = [:]

    for p in paths.sorted() {
        let components = p.split(separator: "/").map(String.init)
        if components.count == 1 {
            tree["(root)", default: []].append(components[0])
        } else {
            let folder = components.dropLast().joined(separator: "/")
            let file = components.last ?? ""
            tree[folder, default: []].append(file)
        }
    }

    if let rootFiles = tree["(root)"] {
        for file in rootFiles {
            print("  ├── 📄 \(file)")
        }
    }

    let folders = tree.keys.filter { $0 != "(root)" }.sorted()
    for (idx, folder) in folders.enumerated() {
        let isLastFolder = (idx == folders.count - 1)
        let branch = isLastFolder ? "└──" : "├──"
        print("  \(branch) 📁 \(folder)/")

        let files = tree[folder] ?? []
        for (fIdx, file) in files.enumerated() {
            let isLastFile = (fIdx == files.count - 1)
            let fileIndent = isLastFolder ? "      " : "  │   "
            let subBranch = isLastFile ? "└──" : "├──"
            print("\(fileIndent)\(subBranch) 📄 \(file)")
        }
    }
    print("")
}

/// Prints a formatted audit table of all evaluated files with per-file decision latency.
public func printAuditTable(organizedFiles: [OrganizedFile]) {
    print("┌───────────────────────────────────┬──────────────┬──────────────┬───────────┬──────┬───────────┬───────────┬───────────────────────────────┐")
    print("│ File                              │ Domain       │ Workflow     │ Sensitive │ Conf │ Jev Model │ Total E2E │ Destination Path              │")
    print("├───────────────────────────────────┼──────────────┼──────────────┼───────────┼──────┼───────────┼───────────┼───────────────────────────────┤")

    for o in organizedFiles {
        let file = String(o.file.relativePath.prefix(33)).padding(toLength: 33, withPad: " ", startingAt: 0)
        let domain = String(o.decision.domain.rawValue.prefix(12)).padding(toLength: 12, withPad: " ", startingAt: 0)
        let workflow = String(o.decision.workflowStage.rawValue.prefix(12)).padding(toLength: 12, withPad: " ", startingAt: 0)
        let sensitive = (o.decision.isSensitive ? "⚠️  YES" : "   No ").padding(toLength: 9, withPad: " ", startingAt: 0)
        let conf = " \(o.decision.confidenceScore)/3  "
        let jevModel = o.serverDurationMs.map { String(format: "%6.1f ms ", $0) } ?? "    n/a    "
        let totalLatency = String(format: "%6.1f ms ", o.durationMs)
        let dest = String(o.destinationRelativePath.prefix(29)).padding(toLength: 29, withPad: " ", startingAt: 0)

        print("│ \(file) │ \(domain) │ \(workflow) │ \(sensitive) │\(conf)│\(jevModel)│\(totalLatency)│ \(dest) │")
    }

    print("└───────────────────────────────────┴──────────────┴──────────────┴───────────┴──────┴───────────┴───────────┴───────────────────────────────┘")
}

/// Prints aggregate decision latency, throughput, and token consumption metrics.
public func printTelemetrySummary(strategy: OrganizationStrategy, organizedFiles: [OrganizedFile]) {
    guard !organizedFiles.isEmpty else { return }

    let totalDuration = organizedFiles.reduce(0.0) { $0 + $1.durationMs }
    let avgDuration = totalDuration / Double(organizedFiles.count)
    let minDuration = organizedFiles.map(\.durationMs).min() ?? 0.0
    let maxDuration = organizedFiles.map(\.durationMs).max() ?? 0.0

    let serverTimes = organizedFiles.compactMap(\.serverDurationMs)
    let serverComputeLine: String
    let networkOverheadLine: String

    if !serverTimes.isEmpty {
        let avgServerTime = serverTimes.reduce(0.0, +) / Double(serverTimes.count)
        let networkOverhead = max(0.0, avgDuration - avgServerTime)
        serverComputeLine = String(format: "  • Jev Model Compute (Cloud):  %.1f ms / decision (Pure System One model inference)", avgServerTime)
        networkOverheadLine = String(format: "  • Network Transit (RTT):      %.1f ms / request (Trans-Atlantic client ↔ server round-trip)", networkOverhead)
    } else {
        serverComputeLine = "  • Jev Model Compute (Cloud):  n/a (Offline mock simulation)"
        networkOverheadLine = "  • Network Transit (RTT):      n/a (Offline mock simulation)"
    }

    let totalInputTokens = organizedFiles.reduce(0) { $0 + $1.inputTokens }
    let totalOutputTokens = organizedFiles.reduce(0) { $0 + $1.outputTokens }
    let totalTokens = totalInputTokens + totalOutputTokens
    let avgTokens = Double(totalTokens) / Double(organizedFiles.count)

    print("""

    ================================================================================
      ⚡️ JEV DECISION TELEMETRY & LATENCY BREAKDOWN (\(strategy.rawValue.uppercased()) STRATEGY)
    ================================================================================
      • Files Evaluated:            \(organizedFiles.count)
    \(serverComputeLine)
    \(networkOverheadLine)
      • Total End-to-End Latency:   \(String(format: "%.1f ms / file", avgDuration)) (Wall-clock from prompt to decoded object)
      • Latency Range (Min/Max):    \(String(format: "%.1f ms (min)  —  %.1f ms (max)", minDuration, maxDuration))
      • Token Consumption:          \(totalTokens) tokens (\(totalInputTokens) input, \(totalOutputTokens) output)
      • Average Tokens / File:      \(String(format: "%.1f tokens", avgTokens))
    ================================================================================
    """)
}
