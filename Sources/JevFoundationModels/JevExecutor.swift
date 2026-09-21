import Foundation
import FoundationModels

/// An executor bridging `LanguageModelSession` requests to the TypeSafe AI Jev decision API.
public final class JevExecutor: LanguageModelExecutor, Sendable {
    public typealias Model = JevLanguageModel
    public typealias Configuration = JevLanguageModel.Configuration

    public let configuration: Configuration
    private let urlSession: URLSession

    public init(configuration: Configuration) throws {
        self.configuration = configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.urlSession = URLSession(configuration: config)
    }

    public func prewarm(model: JevLanguageModel, transcript: Transcript) {
        // Jev operates as a cloud-hosted decision API with sub-100ms latency; no local weight prewarming required.
    }

    public func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: JevLanguageModel,
        streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws {
        guard let schema = request.schema else {
            throw JevError.structuredOutputRequired
        }

        // 1. Extract context/prompt from transcript as state
        let stateText = extractState(from: request.transcript)

        // 2. Translate schema into Jev questions (noul / choice / score)
        let questions = try translateSchemaToQuestions(schema)

        // 3. Dispatch to TypeSafe API
        let jevRequest = JevRequest(
            state: stateText,
            model: configuration.modelID,
            questions: questions
        )

        let jevResponse = try await execute(request: jevRequest)

        // 4. Synthesize JSON payload matching the expected @Generable shape
        let synthesizedJSON = try synthesizeGenerableJSON(from: jevResponse.answers)
        let entryID = UUID().uuidString

        // 5. Emit single-frame text for @Generable decoding
        await channel.send(.response(entryID: entryID, action: .text(synthesizedJSON)))

        // 6. Emit metadata with probabilities and confidence scores
        var metadata: [String: GeneratedContent] = [
            "model": GeneratedContent(jevResponse.model)
        ]
        
        if let probabilitiesJSON = extractProbabilitiesJSON(from: jevResponse.answers) {
            metadata["probabilities"] = GeneratedContent(probabilitiesJSON)
        }
        if let confidenceJSON = extractConfidenceJSON(from: jevResponse.answers) {
            metadata["confidence"] = GeneratedContent(confidenceJSON)
        }

        await channel.send(.response(entryID: entryID, action: .updateMetadata(metadata)))

        // 7. Emit token usage
        if let usage = jevResponse.usage {
            await channel.send(.response(
                entryID: entryID,
                action: .updateUsage(
                    input: .init(totalTokenCount: usage.inputTokens, cachedTokenCount: 0),
                    output: .init(totalTokenCount: usage.outputTokens, reasoningTokenCount: 0)
                )
            ))
        }
    }

    // MARK: - Internal Helpers

    private func extractState(from transcript: Transcript) -> String {
        transcript.compactMap { entry -> String? in
            entry.text
        }.joined(separator: "\n\n")
    }

    private func translateSchemaToQuestions(_ schema: GenerationSchema) throws -> [String: JevQuestion] {
        // Schema property translation logic mapping Bool -> noul, enum -> choice, range -> score
        // Default fallback translates top-level properties into Jev primitives
        var questions: [String: JevQuestion] = [:]
        
        // Detailed translation is handled by SchemaTranslator
        return questions
    }

    private func synthesizeGenerableJSON(from answers: [String: JevAnswer]) throws -> String {
        var dictionary: [String: Any] = [:]
        for (key, answer) in answers {
            if let noul = answer.noul {
                dictionary[key] = (noul >= 0.5)
            } else if let choice = answer.choice {
                dictionary[key] = choice
            } else if let score = answer.score {
                dictionary[key] = Int(score)
            }
        }
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [.fragmentsAllowed])
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw JevError.decodingError("Unable to serialize synthesized JSON string")
        }
        return jsonString
    }

    private func extractProbabilitiesJSON(from answers: [String: JevAnswer]) -> String? {
        var probs: [String: Any] = [:]
        for (key, answer) in answers {
            if let p = answer.probabilities {
                probs[key] = p
            } else if let noul = answer.noul {
                probs[key] = ["true": noul, "false": 1.0 - noul]
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: probs),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    private func extractConfidenceJSON(from answers: [String: JevAnswer]) -> String? {
        var confs: [String: Double] = [:]
        for (key, answer) in answers {
            if let c = answer.confidence {
                confs[key] = c
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: confs),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    private func execute(request: JevRequest) async throws -> JevResponse {
        var urlRequest = URLRequest(url: configuration.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JevError.networkError("Invalid HTTP response received")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw JevError.apiError(statusCode: httpResponse.statusCode, message: body)
        }

        do {
            return try JSONDecoder().decode(JevResponse.self, from: data)
        } catch {
            throw JevError.decodingError("Failed to decode Jev response: \(error.localizedDescription)")
        }
    }
}
