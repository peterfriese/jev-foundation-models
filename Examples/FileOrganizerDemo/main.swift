import Foundation
import FoundationModels
import JevFoundationModels

// MARK: - CLI Configuration & Entry Point

printDemoBanner()

let arguments = ProcessInfo.processInfo.arguments

var targetDirectory: URL?
var selectedStrategy: OrganizationStrategy = .domain
var shouldApplyMoves = false
var isDemoMode = false

var idx = 1
while idx < arguments.count {
    let arg = arguments[idx]
    switch arg {
    case "--demo":
        isDemoMode = true
    case "--path":
        if idx + 1 < arguments.count {
            targetDirectory = URL(fileURLWithPath: arguments[idx + 1])
            idx += 1
        }
    case "--strategy":
        if idx + 1 < arguments.count {
            selectedStrategy = OrganizationStrategy(rawValue: arguments[idx + 1]) ?? .domain
            idx += 1
        }
    case "--apply":
        shouldApplyMoves = true
    case "--dry-run":
        shouldApplyMoves = false
    default:
        break
    }
    idx += 1
}

if targetDirectory == nil && !isDemoMode {
    isDemoMode = true
}

// MARK: - 1. Resolve Transport & Model

let apiKey = resolveAPIKey()
let model: JevLanguageModel

if let key = apiKey {
    print("🔑 Live TypeSafe AI API key detected. Evaluating against Jev cloud endpoint.")
    model = JevLanguageModel(apiKey: key)
} else {
    if targetDirectory != nil && shouldApplyMoves {
        print("❌ Error: TYPESAFE_API_KEY is required when using --apply on actual directories.")
        print("   The deterministic offline mock is only permitted in --demo mode or --dry-run mode.")
        exit(1)
    }
    print("ℹ️  No TYPESAFE_API_KEY detected. Running in deterministic offline demonstration mode.")
    model = JevLanguageModel(apiKey: "offline-mock", transport: createOfflineMockTransport())
}

// MARK: - 2. Configure Dynamic Profile & LanguageModelSession

let auditModifier = TelemetryAuditModifier(
    auditTag: "cli-organizer",
    onPrompt: { _ in
        // Hook called before each file's prompt is processed
    },
    onResponse: { _ in
        // Hook called immediately after response synthesis
    }
)

let profile = DirectoryOrganizerProfile(
    model: model,
    auditLogger: auditModifier
)

let session = LanguageModelSession(profile: profile)

// =============================================================================
// DEMO MODE: Sandbox Walkthrough with Live Profile Adaptation
// =============================================================================

if isDemoMode {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("jev-file-organizer-\(UUID().uuidString.prefix(8))")

    try SampleData.populateSandbox(at: tempDir)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let organizer = FileOrganizer(session: session)
    let initialFiles = try organizer.discoverFiles(in: tempDir)

    printDirectoryTree(
        title: "Initial Unorganized Directory (\(tempDir.path))",
        paths: initialFiles.map(\.relativePath)
    )

    // -------------------------------------------------------------------------
    // PASS 1: Domain-Specific Categorization
    // -------------------------------------------------------------------------
    session.properties.organizationStrategy = .domain
    session.properties.quarantineSensitive = true

    printStrategyBanner(strategy: .domain, quarantine: true)

    print("▶ Evaluating files with Jev System One (Domain Dynamic Profile)...")
    let pass1Results = try await organizer.organize(directoryURL: tempDir, applyChanges: false) { file, result, current, total in
        let serverStr = result.serverDurationMs.map { String(format: "Jev: %.0fms", $0) } ?? "Jev: n/a"
        let totalStr = String(format: "total: %.0fms", result.durationMs)
        let tokenStr = result.inputTokens > 0 ? " • \(result.inputTokens + result.outputTokens) tok" : ""
        print("  [\(current)/\(total)] \(result.file.relativePath) ──► \(result.destinationRelativePath) (\(serverStr), \(totalStr)\(tokenStr))")
    }

    printAuditTable(organizedFiles: pass1Results)
    printTelemetrySummary(strategy: .domain, organizedFiles: pass1Results)

    printDirectoryTree(
        title: "Resulting Structure (Domain Strategy)",
        paths: pass1Results.map(\.destinationRelativePath)
    )

    // -------------------------------------------------------------------------
    // PASS 2: Dynamic Profile Live Adaptation (Workflow Triaging)
    // -------------------------------------------------------------------------
    print("\n--------------------------------------------------------------------------------")
    print("🔄 DYNAMIC PROFILE ADAPTATION: Switching session.properties.organizationStrategy")
    print("   Notice: We do NOT reallocate or rebuild the LanguageModelSession.")
    print("   The DynamicProfile reacts to property updates and injects workflow instructions!")
    print("--------------------------------------------------------------------------------")

    session.properties.organizationStrategy = .workflow

    printStrategyBanner(strategy: .workflow, quarantine: true)

    print("▶ Re-evaluating files under Workflow Dynamic Profile...")
    let pass2Results = try await organizer.organize(directoryURL: tempDir, applyChanges: false) { file, result, current, total in
        let serverStr = result.serverDurationMs.map { String(format: "Jev: %.0fms", $0) } ?? "Jev: n/a"
        let totalStr = String(format: "total: %.0fms", result.durationMs)
        let tokenStr = result.inputTokens > 0 ? " • \(result.inputTokens + result.outputTokens) tok" : ""
        print("  [\(current)/\(total)] \(result.file.relativePath) ──► \(result.destinationRelativePath) (\(serverStr), \(totalStr)\(tokenStr))")
    }

    printAuditTable(organizedFiles: pass2Results)
    printTelemetrySummary(strategy: .workflow, organizedFiles: pass2Results)

    printDirectoryTree(
        title: "Resulting Structure (Workflow Strategy)",
        paths: pass2Results.map(\.destinationRelativePath)
    )

    // -------------------------------------------------------------------------
    // Architectural Summary
    // -------------------------------------------------------------------------
    print("""

    ================================================================================
      Key Takeaways: Jev + Apple Foundation Models Dynamic Profiles
    ================================================================================
      1. Declarative Dynamic Profiles:
         Define session profiles using SwiftUI-like syntax (`DynamicProfileBuilder`),
         binding model parameters, instructions, and lifecycle hooks into one unit.

      2. Reactive State with `@SessionPropertyEntry`:
         `session.properties.organizationStrategy` adapts model behavior at runtime
         without recreating `LanguageModelSession` instances or tearing down state.

      3. Multi-Faceted System One Decisions:
         In a single sub-100ms request, Jev evaluates:
         • Categorical Choice:   Domain & Workflow selection
         • Calibrated Noul:      Credential & secret detection (`isSensitive`)
         • Rubric Score:         Confidence calibration (`confidenceScore` 0...3)

      4. Turn Isolation via `.historyTransform`:
         Keeps batch directory processing stateless per file, preventing earlier
         prompts from bleeding into later evaluations.
    ================================================================================
    """)
} else if let dir = targetDirectory {
    // =============================================================================
    // TARGET DIRECTORY MODE
    // =============================================================================
    session.properties.organizationStrategy = selectedStrategy
    session.properties.quarantineSensitive = true

    printStrategyBanner(strategy: selectedStrategy, quarantine: true)

    let organizer = FileOrganizer(session: session)
    let initialFiles = try organizer.discoverFiles(in: dir)

    if initialFiles.isEmpty {
        print("⚠️ No eligible files found in \(dir.path).")
        exit(0)
    }

    printDirectoryTree(
        title: "Found \(initialFiles.count) files in \(dir.path)",
        paths: initialFiles.map(\.relativePath)
    )

    print("▶ Evaluating \(initialFiles.count) files via Jev System One...")
    let results = try await organizer.organize(
        directoryURL: dir,
        applyChanges: shouldApplyMoves
    ) { file, result, current, total in
        let serverStr = result.serverDurationMs.map { String(format: "Jev: %.0fms", $0) } ?? "Jev: n/a"
        let totalStr = String(format: "total: %.0fms", result.durationMs)
        let tokenStr = result.inputTokens > 0 ? " • \(result.inputTokens + result.outputTokens) tok" : ""
        print("  [\(current)/\(total)] \(result.file.relativePath) ──► \(result.destinationRelativePath) (\(serverStr), \(totalStr)\(tokenStr))")
    }

    printAuditTable(organizedFiles: results)
    printTelemetrySummary(strategy: selectedStrategy, organizedFiles: results)

    if shouldApplyMoves {
        print("✅ Files successfully moved on disk into arranged directories.")
    } else {
        print("ℹ️  Dry-run complete. Re-run with --apply to perform actual filesystem moves.")
    }
}
