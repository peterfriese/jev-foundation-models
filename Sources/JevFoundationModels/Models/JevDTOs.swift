import Foundation

// MARK: - Jev Request Payloads

public struct JevRequest: Codable, Sendable, Equatable {
    public let state: String
    public let model: String
    public let questions: [String: JevQuestion]

    public init(state: String, model: String = "jev-latest", questions: [String: JevQuestion]) {
        self.state = state
        self.model = model
        self.questions = questions
    }
}

public enum JevQuestion: Codable, Sendable, Equatable {
    case noul(instructions: String)
    case choice(instructions: String, criteria: [String: String])
    case score(instructions: String, criteria: [String])

    private enum CodingKeys: String, CodingKey {
        case type, instructions, criteria
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .noul(let instructions):
            try container.encode("noul", forKey: .type)
            try container.encode(instructions, forKey: .instructions)
        case .choice(let instructions, let criteria):
            try container.encode("choice", forKey: .type)
            try container.encode(instructions, forKey: .instructions)
            try container.encode(criteria, forKey: .criteria)
        case .score(let instructions, let criteria):
            try container.encode("score", forKey: .type)
            try container.encode(instructions, forKey: .instructions)
            try container.encode(criteria, forKey: .criteria)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let instructions = try container.decode(String.self, forKey: .instructions)
        switch type {
        case "noul":
            self = .noul(instructions: instructions)
        case "choice":
            let criteria = try container.decode([String: String].self, forKey: .criteria)
            self = .choice(instructions: instructions, criteria: criteria)
        case "score":
            let criteria = try container.decode([String].self, forKey: .criteria)
            self = .score(instructions: instructions, criteria: criteria)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown primitive type: \(type)")
        }
    }
}

// MARK: - Jev Response Payloads

public struct JevResponse: Codable, Sendable, Equatable {
    public let model: String
    public let answers: [String: JevAnswer]
    public let usage: JevUsage?

    public init(model: String, answers: [String: JevAnswer], usage: JevUsage? = nil) {
        self.model = model
        self.answers = answers
        self.usage = usage
    }
}

public struct JevUsage: Codable, Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

public struct JevAnswer: Codable, Sendable, Equatable {
    public let type: String
    public let noul: Double?
    public let choice: String?
    public let score: Double?
    public let confidence: Double?
    public let probabilities: [String: Double]?

    public init(
        type: String,
        noul: Double? = nil,
        choice: String? = nil,
        score: Double? = nil,
        confidence: Double? = nil,
        probabilities: [String: Double]? = nil
    ) {
        self.type = type
        self.noul = noul
        self.choice = choice
        self.score = score
        self.confidence = confidence
        self.probabilities = probabilities
    }
}
