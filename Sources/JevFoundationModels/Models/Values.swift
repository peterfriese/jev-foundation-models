import Foundation

// See tech-notes/0006-http-resilience-and-confidence-routing.md

// MARK: - Probability

/// Represents the calibrated probability of truth for a boolean (`noul`) question.
///
/// In TypeSafe AI's Jev model, a `noul` question carries no separate confidence score.
/// The probability *is* the signal: a value near 0.5 communicates maximum epistemic uncertainty,
/// while both 0.0 and 1.0 represent maximum certainty.
public struct Probability: Sendable, Hashable, Comparable, Codable, ExpressibleByFloatLiteral, CustomStringConvertible {
    public let value: Double

    /// Clamps the input value into `0.0...1.0`.
    ///
    /// - Note: Traps if `value` is `NaN`.
    public init(clamping value: Double) {
        precondition(!value.isNaN, "Probability cannot be NaN")
        self.value = min(max(value, 0.0), 1.0)
    }

    /// Initializes a `Probability` only if `value` is a finite number in `0.0...1.0`.
    public init?(exactly value: Double) {
        guard !value.isNaN, (0.0...1.0).contains(value) else { return nil }
        self.value = value
    }

    public init(floatLiteral value: Double) {
        self.init(clamping: value)
    }

    /// Measures the distance from maximum uncertainty (0.5).
    ///
    /// Both 0.0 and 1.0 map to 1.0 (decisive), whereas 0.5 maps to 0.5 (undecided).
    /// Used for gating decisions where a confident "no" is just as actionable as a confident "yes".
    public var decisiveness: Double {
        max(value, 1.0 - value)
    }

    public static func < (lhs: Probability, rhs: Probability) -> Bool {
        lhs.value < rhs.value
    }

    public var description: String {
        String(value)
    }

    // MARK: - Comparison against Double

    public static func == (lhs: Probability, rhs: Double) -> Bool {
        lhs.value == rhs
    }

    public static func == (lhs: Double, rhs: Probability) -> Bool {
        lhs == rhs.value
    }

    public static func < (lhs: Probability, rhs: Double) -> Bool {
        lhs.value < rhs
    }

    public static func < (lhs: Double, rhs: Probability) -> Bool {
        lhs < rhs.value
    }

    public static func > (lhs: Probability, rhs: Double) -> Bool {
        lhs.value > rhs
    }

    public static func > (lhs: Double, rhs: Probability) -> Bool {
        lhs > rhs.value
    }

    public static func <= (lhs: Probability, rhs: Double) -> Bool {
        lhs.value <= rhs
    }

    public static func <= (lhs: Double, rhs: Probability) -> Bool {
        lhs <= rhs.value
    }

    public static func >= (lhs: Probability, rhs: Double) -> Bool {
        lhs.value >= rhs
    }

    public static func >= (lhs: Double, rhs: Probability) -> Bool {
        lhs >= rhs.value
    }

    // MARK: - Codable

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(Double.self)
        guard let probability = Probability(exactly: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Probability must be a finite number between 0.0 and 1.0, got \(raw)"
            )
        }
        self = probability
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Global Comparison Operators for Optional Probability

public func == (lhs: Probability?, rhs: Double) -> Bool {
    lhs?.value == rhs
}

public func == (lhs: Double, rhs: Probability?) -> Bool {
    rhs?.value == lhs
}

public func != (lhs: Probability?, rhs: Double) -> Bool {
    !(lhs == rhs)
}

public func != (lhs: Double, rhs: Probability?) -> Bool {
    !(lhs == rhs)
}

// MARK: - ScoreValue

/// Represents the probability-weighted answer returned for a rubric `score` question.
///
/// Because `value` is probability-weighted across discrete rubric levels, it can land
/// between integer steps (e.g., 1.30 on a 3-level rubric means "predominantly level 1, leaning toward level 2").
public struct ScoreValue: Sendable, Hashable, CustomStringConvertible {
    /// The continuous probability-weighted score value.
    public let value: Double

    /// Optional descriptions of each rubric level.
    public let legend: [Int: String]

    /// Calibrated probabilities per rubric level index.
    public let probabilities: [Int: Double]

    /// Calibrated confidence score (0.0 to 1.0).
    public let confidence: Double

    public init(
        value: Double,
        legend: [Int: String] = [:],
        probabilities: [Int: Double] = [:],
        confidence: Double = 1.0
    ) {
        precondition(!value.isNaN, "Score value cannot be NaN")
        precondition(!confidence.isNaN && (0.0...1.0).contains(confidence), "Confidence must be within 0.0...1.0")
        self.value = value
        self.legend = legend
        self.probabilities = probabilities
        self.confidence = confidence
    }

    /// The nearest discrete whole rubric level.
    public var rounded: Int {
        Int(value.rounded())
    }

    /// Maps the weighted score onto `0.0...1.0`. Returns `nil` if there are fewer than 2 levels.
    public var normalized: Double? {
        let levels = max(legend.count, probabilities.count)
        guard levels >= 2 else { return nil }
        return value / Double(levels - 1)
    }

    public var description: String {
        String(format: "ScoreValue(value: %.2f, rounded: %d, confidence: %.2f)", value, rounded, confidence)
    }
}

extension ScoreValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case score, legend, probabilities, confidence
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Double.self, forKey: .score)
        let rawLegend = try container.decodeIfPresent([String: String].self, forKey: .legend) ?? [:]
        let rawProbabilities = try container.decodeIfPresent([String: Double].self, forKey: .probabilities) ?? [:]
        let confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 1.0

        guard !confidence.isNaN, (0.0...1.0).contains(confidence) else {
            throw DecodingError.dataCorruptedError(
                forKey: .confidence,
                in: container,
                debugDescription: "Confidence must be within 0.0...1.0, got \(confidence)"
            )
        }

        func parseIndexed<T>(_ source: [String: T], key: CodingKeys) throws -> [Int: T] {
            var result: [Int: T] = [:]
            for (rawKey, item) in source {
                guard let index = Int(rawKey) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: key,
                        in: container,
                        debugDescription: "Rubric level key '\(rawKey)' is not an integer"
                    )
                }
                guard result.updateValue(item, forKey: index) == nil else {
                    throw DecodingError.dataCorruptedError(
                        forKey: key,
                        in: container,
                        debugDescription: "Duplicate rubric level index \(index)"
                    )
                }
            }
            return result
        }

        let legend = try parseIndexed(rawLegend, key: .legend)
        let probabilities = try parseIndexed(rawProbabilities, key: .probabilities)

        guard !value.isNaN else {
            throw DecodingError.dataCorruptedError(
                forKey: .score,
                in: container,
                debugDescription: "Score must not be NaN"
            )
        }

        self.init(
            value: value,
            legend: legend,
            probabilities: probabilities,
            confidence: confidence
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .score)
        try container.encode(
            Dictionary(uniqueKeysWithValues: legend.map { (String($0.key), $0.value) }),
            forKey: .legend
        )
        try container.encode(
            Dictionary(uniqueKeysWithValues: probabilities.map { (String($0.key), $0.value) }),
            forKey: .probabilities
        )
        try container.encode(confidence, forKey: .confidence)
    }
}
