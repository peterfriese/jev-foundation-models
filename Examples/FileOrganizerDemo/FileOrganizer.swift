import Foundation
import FoundationModels
import JevFoundationModels
#if canImport(PDFKit)
import PDFKit
#endif

// MARK: - @Generable Decision Primitives

/// Semantic domain classification for files.
@Generable
public enum ContentDomain: String, CaseIterable, Sendable {
    case finance = "finance"
    case engineering = "engineering"
    case legal = "legal"
    case documentation = "documentation"
    case personal = "personal"
}

/// Actionability stage for workflow-based organization.
@Generable
public enum WorkflowStage: String, CaseIterable, Sendable {
    case actionRequired = "action_required"
    case reference = "reference"
    case archive = "archive"
}

/// A composite System One decision evaluating domain, workflow stage, sensitivity, and confidence.
@Generable
public struct FileTriageDecision: Sendable {
    @Guide(description: "The primary semantic topic of the file")
    public var domain: ContentDomain

    @Guide(description: "Recommended workflow triage bucket based on immediate actionability")
    public var workflowStage: WorkflowStage

    @Guide(description: "True if this file contains sensitive secrets, API keys, passwords, credentials, or private PII")
    public var isSensitive: Bool

    @Guide(description: "Decision confidence rating from 0 (ambiguous/uncertain) to 3 (clear definitive match)", .range(0...3))
    public var confidenceScore: Int

    public init(
        domain: ContentDomain,
        workflowStage: WorkflowStage,
        isSensitive: Bool,
        confidenceScore: Int
    ) {
        self.domain = domain
        self.workflowStage = workflowStage
        self.isSensitive = isSensitive
        self.confidenceScore = confidenceScore
    }
}

// MARK: - Data Models

/// A discovered file ready for evaluation.
public struct DiscoveredFile: Sendable, Hashable {
    public let url: URL
    public let relativePath: String
    public let sizeInBytes: Int
    public let contentSample: String

    public init(url: URL, relativePath: String, sizeInBytes: Int, contentSample: String) {
        self.url = url
        self.relativePath = relativePath
        self.sizeInBytes = sizeInBytes
        self.contentSample = contentSample
    }
}

/// An organized file with triage metadata and computed destination.
public struct OrganizedFile: Sendable {
    public let file: DiscoveredFile
    public let decision: FileTriageDecision
    public let destinationRelativePath: String
    public let domainProbability: Double?
    public let sensitiveProbability: Double?
    public let durationMs: Double
    public let serverDurationMs: Double?
    public let inputTokens: Int
    public let outputTokens: Int

    public init(
        file: DiscoveredFile,
        decision: FileTriageDecision,
        destinationRelativePath: String,
        domainProbability: Double?,
        sensitiveProbability: Double?,
        durationMs: Double,
        serverDurationMs: Double? = nil,
        inputTokens: Int = 0,
        outputTokens: Int = 0
    ) {
        self.file = file
        self.decision = decision
        self.destinationRelativePath = destinationRelativePath
        self.domainProbability = domainProbability
        self.sensitiveProbability = sensitiveProbability
        self.durationMs = durationMs
        self.serverDurationMs = serverDurationMs
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

// MARK: - File Organizer Engine

/// An engine that parses directory contents and organizes them using Jev System One
/// and Apple Foundation Models Dynamic Profiles.
public struct FileOrganizer: Sendable {
    public let session: LanguageModelSession

    public init(session: LanguageModelSession) {
        self.session = session
    }

    // MARK: - Directory Discovery

    /// Scans a directory for non-hidden regular files and extracts a preview snippet.
    public func discoverFiles(in directoryURL: URL) throws -> [DiscoveredFile] {
        var results: [DiscoveredFile] = []
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .isHiddenKey]
        let fileManager = FileManager.default
        let resolvedDirectory = directoryURL.resolvingSymlinksInPath()

        guard let enumerator = fileManager.enumerator(
            at: resolvedDirectory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: resourceKeys)
            guard values.isRegularFile == true, values.isHidden != true else { continue }

            let fileSize = values.fileSize ?? 0
            let resolvedFile = fileURL.resolvingSymlinksInPath()
            var relative = resolvedFile.path.replacingOccurrences(of: resolvedDirectory.path, with: "")
            while relative.hasPrefix("/") {
                relative.removeFirst()
            }

            // Read up to 2048 bytes of text for content inspection
            let sample = Self.extractSnippet(from: resolvedFile, maxBytes: 2048)
            results.append(DiscoveredFile(
                url: resolvedFile,
                relativePath: relative,
                sizeInBytes: fileSize,
                contentSample: sample
            ))
        }

        return results.sorted { $0.relativePath < $1.relativePath }
    }

    /// Safely extracts leading plain-text characters from a file.
    public static func extractSnippet(from url: URL, maxBytes: Int) -> String {
        if url.pathExtension.lowercased() == "pdf" {
            #if canImport(PDFKit)
            if let doc = PDFDocument(url: url),
               let page = doc.page(at: 0),
               let text = page.string,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            #endif
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return "(unreadable)" }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: maxBytes) else { return "(empty)" }
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let ascii = String(data: data, encoding: .ascii) {
            return ascii.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "(binary or unsupported encoding)"
    }

    // MARK: - Formatting Prompt

    public static func formatPrompt(for file: DiscoveredFile) -> String {
        """
        Evaluate this file:
        - Filename: \(file.relativePath)
        - Size: \(file.sizeInBytes) bytes
        - Content Excerpt:
        \"\"\"
        \(file.contentSample.prefix(1200))
        \"\"\"
        """
    }

    // MARK: - Triage and Path Resolution

    /// Resolves the destination folder path given the current dynamic profile settings and decision.
    public static func resolveDestinationPath(
        for file: DiscoveredFile,
        decision: FileTriageDecision,
        strategy: OrganizationStrategy,
        quarantineSensitive: Bool
    ) -> String {
        let filename = URL(fileURLWithPath: file.relativePath).lastPathComponent

        // Rule 1: High-priority quarantine for credentials/secrets
        if quarantineSensitive && decision.isSensitive {
            return "Quarantine_Vault/\(filename)"
        }

        // Rule 2: Low-confidence items routed to human review
        if decision.confidenceScore < 2 {
            return "Review_Queue/\(filename)"
        }

        // Rule 3: Strategy-specific arrangement
        switch strategy {
        case .workflow:
            let folderName: String
            switch decision.workflowStage {
            case .actionRequired: folderName = "Workflow/1_Action_Required"
            case .reference:      folderName = "Workflow/2_Reference_Material"
            case .archive:        folderName = "Workflow/3_Archive"
            }
            return "\(folderName)/\(filename)"

        case .domain:
            let folderName: String
            switch decision.domain {
            case .finance:       folderName = "Organized/Finance_and_Billing"
            case .engineering:   folderName = "Organized/Engineering_and_Code"
            case .legal:         folderName = "Organized/Legal_and_Contracts"
            case .documentation: folderName = "Organized/Documentation"
            case .personal:      folderName = "Organized/Personal_Notes"
            }
            return "\(folderName)/\(filename)"
        }
    }

    // MARK: - Evaluation

    /// Evaluates a single file using the session configured with the dynamic profile.
    public func evaluate(file: DiscoveredFile) async throws -> OrganizedFile {
        let startTime = CFAbsoluteTimeGetCurrent()
        let prompt = Self.formatPrompt(for: file)

        let response = try await session.respond(
            to: prompt,
            generating: FileTriageDecision.self
        )

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        let domainProb = response.probabilities["domain"]?[response.content.domain.rawValue]
        let sensitiveProb = response.probability(for: "isSensitive")

        let destination = Self.resolveDestinationPath(
            for: file,
            decision: response.content,
            strategy: session.properties.organizationStrategy,
            quarantineSensitive: session.properties.quarantineSensitive
        )

        let inputTokens = response.usage.input.totalTokenCount
        let outputTokens = response.usage.output.totalTokenCount
        let serverMs = response.serverDurationMs

        return OrganizedFile(
            file: file,
            decision: response.content,
            destinationRelativePath: destination,
            domainProbability: domainProb,
            sensitiveProbability: sensitiveProb,
            durationMs: duration,
            serverDurationMs: serverMs,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
    }

    // MARK: - Execution

    /// Evaluates all files in a directory and optionally moves them to their arranged destinations.
    public func organize(
        directoryURL: URL,
        applyChanges: Bool,
        onFileEvaluated: (@Sendable (DiscoveredFile, OrganizedFile, Int, Int) -> Void)? = nil
    ) async throws -> [OrganizedFile] {
        let discovered = try discoverFiles(in: directoryURL)
        var organized: [OrganizedFile] = []

        for (index, file) in discovered.enumerated() {
            let result = try await evaluate(file: file)
            organized.append(result)
            onFileEvaluated?(file, result, index + 1, discovered.count)

            if applyChanges {
                let fileManager = FileManager.default
                let destURL = directoryURL.appendingPathComponent(result.destinationRelativePath)
                let destFolder = destURL.deletingLastPathComponent()
                try fileManager.createDirectory(at: destFolder, withIntermediateDirectories: true)
                try fileManager.moveItem(at: file.url, to: destURL)
            }
        }

        return organized
    }
}
