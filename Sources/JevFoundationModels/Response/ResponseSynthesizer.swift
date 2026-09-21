import Foundation

/// Synthesizes Jev System One answers into valid JSON payloads matching `@Generable` shapes.
public struct ResponseSynthesizer: Sendable {
    public init() {}

    /// Synthesizes the text payload to be delivered through `LanguageModelExecutorGenerationChannel`.
    ///
    /// For `@Generable struct` (object root), this returns a canonical JSON string.
    /// For `@Generable enum` (choice root), this returns the raw unquoted enum case string
    /// as expected by Apple's Foundation Models internal decoder.
    public func synthesize(
        answers: [String: JevAnswer],
        layout: SchemaRootLayout
    ) throws -> String {
        switch layout {
        case .object(let properties, _):
            let dictionary = try buildObjectDictionary(properties: properties, answers: answers)
            let data = try JSONSerialization.data(
                withJSONObject: dictionary,
                options: [.sortedKeys, .fragmentsAllowed]
            )
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw JevError.decodingError("Failed to convert synthesized dictionary to UTF-8 JSON string.")
            }
            return jsonString

        case .choice(let options, let questionKey):
            let answer = answers[questionKey]
            guard let choice = answer?.choice ?? options.first else {
                throw JevError.decodingError("No choice answer returned for root enum question '\(questionKey)'.")
            }
            // Root enum expects bare case string for FoundationModels decoding
            return choice

        case .boolean(let questionKey):
            let answer = answers[questionKey]
            let boolValue: Bool
            if let noul = answer?.noul {
                boolValue = (noul >= 0.5)
            } else if let choice = answer?.choice {
                boolValue = (choice.lowercased() == "true")
            } else {
                boolValue = false
            }
            return boolValue ? "true" : "false"

        case .score(let min, let max, let isInteger, let questionKey):
            let answer = answers[questionKey]
            let value = computeScoreValue(answer: answer, min: min, max: max, isInteger: isInteger)
            if isInteger {
                return "\(Int(round(value)))"
            } else {
                return "\(value)"
            }
        }
    }

    /// Extracts calibrated probability distributions from Jev answers into a JSON string.
    public func extractProbabilitiesJSON(from answers: [String: JevAnswer]) -> String? {
        var probs: [String: Any] = [:]
        for (key, answer) in answers {
            if let distribution = answer.probabilities {
                probs[key] = distribution
            } else if let noul = answer.noul {
                probs[key] = [
                    "true": noul,
                    "false": max(0.0, 1.0 - noul)
                ]
            }
        }
        guard !probs.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: probs, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    /// Extracts confidence scores from Jev answers into a JSON string.
    public func extractConfidenceJSON(from answers: [String: JevAnswer]) -> String? {
        var confs: [String: Double] = [:]
        for (key, answer) in answers {
            if let confidence = answer.confidence {
                confs[key] = confidence
            } else if let noul = answer.noul {
                // Confidence for noul reflects distance from 0.5 maximum uncertainty
                confs[key] = abs(noul - 0.5) * 2.0
            }
        }
        guard !confs.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: confs, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return json
    }

    // MARK: - Internal Helpers

    private func buildObjectDictionary(
        properties: [String: SchemaPropertyDescriptor],
        answers: [String: JevAnswer]
    ) throws -> [String: Any] {
        var dictionary: [String: Any] = [:]

        for (name, descriptor) in properties {
            if let value = extractPropertyValue(descriptor: descriptor, answers: answers) {
                dictionary[name] = value
            } else if descriptor.isRequired {
                // Provide a safe default for required fields if answer was omitted
                dictionary[name] = defaultFallbackValue(for: descriptor)
            }
        }

        return dictionary
    }

    private func extractPropertyValue(
        descriptor: SchemaPropertyDescriptor,
        answers: [String: JevAnswer]
    ) -> Any? {
        let answer = answers[descriptor.questionKey]

        switch descriptor.kind {
        case .boolean:
            if let noul = answer?.noul {
                return (noul >= 0.5)
            } else if let choice = answer?.choice {
                return (choice.lowercased() == "true")
            }
            return nil

        case .choice(let options):
            if let choice = answer?.choice {
                return choice
            }
            return options.first

        case .score(let min, let max, let isInteger):
            guard answer != nil else { return nil }
            let val = computeScoreValue(answer: answer, min: min, max: max, isInteger: isInteger)
            return isInteger ? Int(round(val)) : val

        case .nested(let childDescriptors):
            var childDict: [String: Any] = [:]
            for (childName, childDesc) in childDescriptors {
                if let childVal = extractPropertyValue(descriptor: childDesc, answers: answers) {
                    childDict[childName] = childVal
                } else if childDesc.isRequired {
                    childDict[childName] = defaultFallbackValue(for: childDesc)
                }
            }
            return childDict
        }
    }

    private func computeScoreValue(
        answer: JevAnswer?,
        min: Double,
        max: Double,
        isInteger: Bool
    ) -> Double {
        guard let rawScore = answer?.score else {
            return min
        }

        let computed: Double
        if rawScore >= min && rawScore <= max {
            computed = rawScore
        } else if rawScore >= 0 && rawScore <= (max - min) {
            // Raw score is a 0-based rubric level index
            computed = min + rawScore
        } else {
            computed = Swift.min(Swift.max(rawScore, min), max)
        }

        let clamped = Swift.min(Swift.max(computed, min), max)
        return isInteger ? round(clamped) : clamped
    }

    private func defaultFallbackValue(for descriptor: SchemaPropertyDescriptor) -> Any {
        switch descriptor.kind {
        case .boolean:
            return false
        case .choice(let options):
            return options.first ?? ""
        case .score(let min, _, let isInteger):
            return isInteger ? Int(min) : min
        case .nested(let children):
            var dict: [String: Any] = [:]
            for (k, v) in children where v.isRequired {
                dict[k] = defaultFallbackValue(for: v)
            }
            return dict
        }
    }
}
