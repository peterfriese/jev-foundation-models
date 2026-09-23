import Foundation
import FoundationModels

/// An executor bridging `LanguageModelSession` requests to the TypeSafe AI Jev decision API.
public final class JevExecutor: LanguageModelExecutor, Sendable {
    public typealias Model = JevLanguageModel
    public typealias Configuration = JevLanguageModel.Configuration

    public let configuration: Configuration
    private let client: JevClient
    private let translator: SchemaTranslator
    private let synthesizer: ResponseSynthesizer

    public init(configuration: Configuration) throws {
        self.configuration = configuration
        self.client = JevClient(configuration: configuration)
        self.translator = SchemaTranslator()
        self.synthesizer = ResponseSynthesizer()
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
        let translation = try translator.translate(schema)

        // 3. Dispatch to TypeSafe API
        let jevRequest = JevRequest(
            state: stateText,
            model: configuration.modelID,
            questions: translation.questions
        )

        let jevResponse = try await client.execute(request: jevRequest)

        // 4. Synthesize payload matching the expected @Generable shape
        let synthesizedText = try synthesizer.synthesize(
            answers: jevResponse.answers,
            layout: translation.layout
        )
        let entryID = UUID().uuidString
        let outputTokenCount = jevResponse.usage?.outputTokens ?? 1

        // 5. Emit single-frame text for @Generable decoding
        await channel.send(.response(
            entryID: entryID,
            action: .appendText(synthesizedText, tokenCount: outputTokenCount)
        ))

        // 6. Emit metadata with probabilities and confidence scores
        var metadata: [String: GeneratedContent] = [
            "model": GeneratedContent(jevResponse.model)
        ]

        if let serverDurationMs = jevResponse.serverDurationMs {
            metadata["serverDurationMs"] = GeneratedContent(String(format: "%.1f", serverDurationMs))
        }

        if let probabilitiesJSON = synthesizer.extractProbabilitiesJSON(from: jevResponse.answers) {
            metadata["probabilities"] = (try? GeneratedContent(json: probabilitiesJSON)) ?? GeneratedContent(probabilitiesJSON)
        }
        if let confidenceJSON = synthesizer.extractConfidenceJSON(from: jevResponse.answers) {
            metadata["confidence"] = (try? GeneratedContent(json: confidenceJSON)) ?? GeneratedContent(confidenceJSON)
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

    public func extractState(from transcript: Transcript) -> String {
        var parts: [String] = []

        for entry in transcript {
            switch entry {
            case .instructions(let instructions):
                for segment in instructions.segments {
                    if case .text(let textSegment) = segment {
                        parts.append(textSegment.content)
                    }
                }
            case .prompt(let prompt):
                for segment in prompt.segments {
                    if case .text(let textSegment) = segment {
                        parts.append(textSegment.content)
                    }
                }
            case .response(let response):
                for segment in response.segments {
                    if case .text(let textSegment) = segment {
                        parts.append(textSegment.content)
                    }
                }
            default:
                break
            }
        }

        let combined = parts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? "Application state evaluation" : combined
    }
}
