import Foundation

/// Represents a saved or incoming article in the read-it-later / knowledge-management library.
public struct Article: Identifiable, Sendable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let byline: String?
    public let url: URL
    public let excerpt: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        byline: String? = nil,
        url: URL,
        excerpt: String
    ) {
        self.id = id
        self.title = title
        self.byline = byline
        self.url = url
        self.excerpt = excerpt
    }
}

/// The layer and rule by which a duplicate was detected.
public enum MatchReason: Sendable, Equatable {
    /// Layer 1: Deterministic match (zero tokens, instantaneous).
    case deterministic(rule: String)

    /// Layer 2: Semantic match via Jev Foundation Models (calibrated probability).
    case semantic(probability: Double, threshold: Double)

    public var description: String {
        switch self {
        case .deterministic(let rule):
            return "Layer 1 (Deterministic: \(rule))"
        case .semantic(let prob, let thresh):
            return String(format: "Layer 2 (Jev System One: %.1f%% ≥ %.1f%% threshold)", prob * 100, thresh * 100)
        }
    }
}

/// A matched duplicate candidate along with the matching rationale.
public struct DuplicateMatch: Sendable, Equatable {
    public let candidate: Article
    public let reason: MatchReason

    public init(candidate: Article, reason: MatchReason) {
        self.candidate = candidate
        self.reason = reason
    }
}

/// The overall deduplication verdict for an incoming article.
public enum DeduplicationVerdict: Sendable, Equatable {
    /// The incoming article is identified as a duplicate of an existing article in the library.
    case duplicate(DuplicateMatch)

    /// The incoming article is unique and safe to save directly.
    case unique
}
