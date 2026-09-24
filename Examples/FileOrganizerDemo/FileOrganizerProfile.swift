import Foundation
import FoundationModels
import JevFoundationModels

// MARK: - Organization Strategy

/// The strategy used to triage and arrange files.
public enum OrganizationStrategy: String, Sendable, CaseIterable {
    /// Categorize by semantic subject matter (Finance, Engineering, Legal, Docs, Personal).
    case domain

    /// Categorize by workflow actionability (Action Required, Reference, Archive).
    case workflow
}

// MARK: - Dynamic Profile Session Properties

extension SessionPropertyValues {
    /// The active organization strategy for dynamic profile adaptation.
    @SessionPropertyEntry
    public var organizationStrategy: OrganizationStrategy = .domain

    /// Whether files flagged as sensitive are quarantined into a secure directory.
    @SessionPropertyEntry
    public var quarantineSensitive: Bool = true
}

// MARK: - Custom Dynamic Profile Modifier

/// A reusable profile modifier that provides structured telemetry logging across profile branches.
public struct TelemetryAuditModifier: LanguageModelSession.DynamicProfileModifier, Sendable {
    public let auditTag: String
    public let onPrompt: (@Sendable (Transcript.Prompt) -> Void)?
    public let onResponse: (@Sendable (Transcript.Response) -> Void)?

    public init(
        auditTag: String = "dynamic-profile",
        onPrompt: (@Sendable (Transcript.Prompt) -> Void)? = nil,
        onResponse: (@Sendable (Transcript.Response) -> Void)? = nil
    ) {
        self.auditTag = auditTag
        self.onPrompt = onPrompt
        self.onResponse = onResponse
    }

    public func body(content: Content) -> some LanguageModelSession.DynamicProfile {
        content
            .onPrompt { prompt in
                onPrompt?(prompt)
            }
            .onResponse { response in
                onResponse?(response)
            }
    }
}

// MARK: - Directory Organizer Dynamic Profile

/// A dynamic session profile that switches model instructions and routing policies at runtime
/// based on `LanguageModelSession` property values.
public struct DirectoryOrganizerProfile: LanguageModelSession.DynamicProfile, Sendable {
    @LanguageModelSession.SessionProperty(\.organizationStrategy) var strategy: OrganizationStrategy
    @LanguageModelSession.SessionProperty(\.quarantineSensitive) var quarantineSensitive: Bool

    public let model: JevLanguageModel
    public let auditLogger: TelemetryAuditModifier?

    public init(
        model: JevLanguageModel,
        auditLogger: TelemetryAuditModifier? = nil
    ) {
        self.model = model
        self.auditLogger = auditLogger
    }

    public var body: some LanguageModelSession.DynamicProfile {
        if strategy == .workflow {
            LanguageModelSession.Profile {
                Instructions("""
                You are analyzing files to organize them into an actionable workflow hierarchy:
                - Action Required: Invoices needing payment, open bug reports, items awaiting signature or review.
                - Reference: Specifications, architecture documents, code files, and user guides.
                - Archive: Historical agreements, completed task logs, or personal scratchpads.
                - Sensitive Content: Detect any secrets, API keys, private passwords, credentials, or confidential PII.
                """)
            }
            .model(model)
            .historyTransform { Self.isolateCurrentTurn($0) }
            .modifier(auditLogger ?? TelemetryAuditModifier(auditTag: "workflow"))
        } else {
            LanguageModelSession.Profile {
                Instructions("""
                You are analyzing files to organize them into domain-specific knowledge folders:
                - Finance & Billing: Invoices, receipts, payout statements, expense summaries.
                - Engineering & Code: Source files, scripts, architectural specs, API definitions.
                - Legal & Contracts: NDAs, employment agreements, vendor terms, licenses.
                - Documentation: Guides, runbooks, READMEs, project plans.
                - Personal Notes: Quick memos, shopping lists, journals.
                - Sensitive Content: Detect any secrets, API keys, private passwords, credentials, or confidential PII.
                """)
            }
            .model(model)
            .historyTransform { Self.isolateCurrentTurn($0) }
            .modifier(auditLogger ?? TelemetryAuditModifier(auditTag: "domain"))
        }
    }

    /// Isolates turns when batch-evaluating multiple files in a directory.
    ///
    /// Preserves system instructions and the current file's prompt while discarding previous
    /// file evaluations so context windows remain predictable and focused.
    public static func isolateCurrentTurn(_ entries: [Transcript.Entry]) -> [Transcript.Entry] {
        let instructions = entries.filter {
            if case .instructions = $0 { return true }
            return false
        }
        if let last = entries.last, case .prompt = last {
            return instructions + [last]
        }
        return entries
    }
}
