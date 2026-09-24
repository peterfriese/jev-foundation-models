import Foundation
import FoundationModels
import JevFoundationModels

// MARK: - @Generable Decision Schema for Apple Foundation Models

@Generable
public struct ArticleDuplicateDecision {
    @Guide(description: """
    Answer true only if the incoming article and the candidate are the SAME article content, \
    judged by substance rather than headline phrasing: the same topic, subject, entities, and key facts — \
    including the same article republished on a different domain, under a different headline. \
    Answer false ONLY when the articles are genuinely different content that merely share a topic or a similar title.
    """)
    public var isDuplicate: Bool

    public init(isDuplicate: Bool) {
        self.isDuplicate = isDuplicate
    }
}

// MARK: - Two-Layer Article Deduplicator

/// A two-layer article deduplication engine combining deterministic string matching with
/// TypeSafe AI's Jev System One decision model bridged via Apple Foundation Models.
public struct ArticleDeduplicator: Sendable {
    /// The Jev Foundation Models language model instance.
    public let model: JevLanguageModel

    /// The calibrated decision threshold for Jev's noul probability. Defaults to 0.60.
    public let threshold: Double

    /// The operational routing policy for turning confidence into actions.
    public let policy: RoutingPolicy

    public init(
        model: JevLanguageModel,
        threshold: Double = 0.60,
        policy: RoutingPolicy = RoutingPolicy(escalateBelow: 0.60, autoAtOrAbove: 0.85)
    ) {
        self.model = model
        self.threshold = threshold
        self.policy = policy
    }

    // MARK: - Layer 1: Deterministic Matching (Zero-Cost, No Network)

    /// Normalizes a URL by lowercasing the host, removing query tracking parameters (utm_*, ref, etc.),
    /// and trimming trailing slashes.
    public static func normalizeURL(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        if let host = components.host, host.hasPrefix("www.") {
            components.host = String(host.dropFirst(4))
        }

        // Strip marketing and referrer query parameters
        let trackingKeys: Set<String> = [
            "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
            "ref", "fbclid", "gclid", "msclkid", "mc_eid"
        ]

        if let queryItems = components.queryItems {
            let filtered = queryItems.filter { !trackingKeys.contains($0.name.lowercased()) }
            components.queryItems = filtered.isEmpty ? nil : filtered
        }

        var result = components.string ?? url.absoluteString
        while result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }

    /// Normalizes a title by lowercasing and collapsing whitespace while strictly preserving punctuation.
    ///
    /// Preserving punctuation ensures domain-critical terms like "C++" never collapse into "c",
    /// and "State of AI 2025" != "State of AI 2026".
    public static func normalizeTitle(_ title: String) -> String {
        title.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Fast, deterministic comparison: catches duplicates with identical normalized URLs or
    /// identical normalized titles with matching bylines.
    public func deterministicMatch(_ incoming: Article, in library: [Article]) -> DuplicateMatch? {
        let incomingNormURL = Self.normalizeURL(incoming.url)
        let incomingNormTitle = Self.normalizeTitle(incoming.title)

        for candidate in library {
            let candidateNormURL = Self.normalizeURL(candidate.url)
            if candidateNormURL == incomingNormURL {
                return DuplicateMatch(candidate: candidate, reason: .deterministic(rule: "Exact normalized URL match"))
            }

            let candidateNormTitle = Self.normalizeTitle(candidate.title)
            if candidateNormTitle == incomingNormTitle,
               let candidateByline = candidate.byline,
               let incomingByline = incoming.byline,
               candidateByline.caseInsensitiveCompare(incomingByline) == .orderedSame {
                return DuplicateMatch(candidate: candidate, reason: .deterministic(rule: "Exact title & byline match"))
            }
        }

        return nil
    }

    // MARK: - Layer 2: Semantic Foundation Models + Jev Decision

    /// Formats the prompt/state block comparing the incoming article against a library candidate.
    public static func formatEvaluationState(incoming: Article, candidate: Article) -> String {
        """
        Incoming article:
        - Title: \(incoming.title)
        - Byline: \(incoming.byline ?? "Unknown")
        - URL: \(incoming.url.absoluteString)
        - Excerpt: \(incoming.excerpt)

        Candidate article:
        - Title: \(candidate.title)
        - Byline: \(candidate.byline ?? "Unknown")
        - URL: \(candidate.url.absoluteString)
        - Excerpt: \(candidate.excerpt)
        """
    }

    /// Evaluates whether an incoming article is a duplicate of a candidate using `LanguageModelSession`.
    public func evaluateSemanticPair(
        incoming: Article,
        candidate: Article
    ) async throws -> (isDuplicate: Bool, probability: Double, judgement: NoulJudgement, tokenUsage: (input: Int, output: Int)) {
        let session = LanguageModelSession(model: model)
        let state = Self.formatEvaluationState(incoming: incoming, candidate: candidate)

        let response = try await session.respond(
            to: state,
            generating: ArticleDuplicateDecision.self
        )

        // Extract calibrated noul probability directly from Jev response metadata
        let probability = response.probability(for: "isDuplicate") ?? (response.content.isDuplicate ? 1.0 : 0.0)
        let judgement = response.judgement(for: "isDuplicate", policy: policy)

        // Operational decision:
        // - .auto with true: decisive duplicate
        // - .confirm: leaning duplicate, prompt user for confirmation
        // - .escalate: model is genuinely unsure (inside undecided band); escalate for manual review
        let isFlagged: Bool
        switch judgement.decision {
        case .auto:
            isFlagged = (judgement.answer == true)
        case .confirm:
            isFlagged = (judgement.answer == true || probability >= threshold)
        case .escalate:
            isFlagged = true
        }

        let usage = (
            input: response.usage.input.totalTokenCount,
            output: response.usage.output.totalTokenCount
        )

        return (isDuplicate: isFlagged, probability: probability, judgement: judgement, tokenUsage: usage)
    }

    // MARK: - Full Deduplication Pipeline

    /// Evaluates an incoming article against the library using the two-layer architecture.
    ///
    /// 1. First tests Layer 1 deterministic matching (0 tokens, 0ms).
    /// 2. If no deterministic match, concurrently evaluates candidates via Layer 2 (Jev System One).
    public func check(
        _ incoming: Article,
        against library: [Article]
    ) async throws -> DeduplicationVerdict {
        // Layer 1: Deterministic check
        if let match = deterministicMatch(incoming, in: library) {
            return .duplicate(match)
        }

        // Layer 2: Semantic check via Jev Foundation Models across candidates concurrently
        return try await withThrowingTaskGroup(of: DuplicateMatch?.self) { group in
            for candidate in library {
                group.addTask {
                    let evaluation = try await evaluateSemanticPair(incoming: incoming, candidate: candidate)
                    if evaluation.isDuplicate {
                        return DuplicateMatch(
                            candidate: candidate,
                            reason: .semantic(
                                probability: evaluation.probability,
                                threshold: threshold,
                                judgement: evaluation.judgement
                            )
                        )
                    }
                    return nil
                }
            }

            for try await match in group {
                if let match = match {
                    // Return first duplicate exceeding calibrated threshold
                    return .duplicate(match)
                }
            }

            return .unique
        }
    }
}
