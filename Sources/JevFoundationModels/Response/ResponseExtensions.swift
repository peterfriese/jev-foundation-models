import Foundation
import FoundationModels

// MARK: - LanguageModelSession.Response Extensions for Jev Telemetry

public extension LanguageModelSession.Response {
    /// The response metadata emitted by `JevExecutor`, containing model ID, confidence scores, and calibrated probabilities.
    var metadata: [String: GeneratedContent] {
        for entry in transcriptEntries {
            if case .response(let r) = entry {
                return r.metadata
            }
        }
        return [:]
    }

    /// Calibrated probability distributions per question, parsed from response metadata.
    ///
    /// For boolean (`noul`) questions, the nested dictionary contains keys `"true"` and `"false"`.
    /// For categorical (`choice`) questions, keys correspond to each candidate option.
    var probabilities: [String: [String: Double]] {
        guard let content = metadata["probabilities"] else { return [:] }
        let rawJSON: String
        if let str = try? content.value(String.self) {
            rawJSON = str
        } else {
            rawJSON = content.jsonString
        }

        guard let data = rawJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] else {
            return [:]
        }
        return dict
    }

    /// Calibrated confidence scores (0.0 to 1.0) per question, parsed from response metadata.
    var confidenceScores: [String: Double] {
        guard let content = metadata["confidence"] else { return [:] }
        let rawJSON: String
        if let str = try? content.value(String.self) {
            rawJSON = str
        } else {
            rawJSON = content.jsonString
        }

        guard let data = rawJSON.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Double] else {
            return [:]
        }
        return dict
    }

    /// Returns the calibrated probability of `true` for a boolean (`noul`) question.
    ///
    /// - Parameter question: The question or property name in the `@Generable` schema.
    /// - Returns: A calibrated probability between 0.0 and 1.0, or `nil` if not available.
    func probability(for question: String) -> Double? {
        if let questionProbs = probabilities[question], let trueProb = questionProbs["true"] {
            return trueProb
        }
        return nil
    }

    /// Returns the confidence score for a given question.
    ///
    /// - Parameter question: The question or property name in the `@Generable` schema.
    /// - Returns: A confidence score between 0.0 and 1.0, or `nil` if not available.
    func confidence(for question: String) -> Double? {
        confidenceScores[question]
    }
}
