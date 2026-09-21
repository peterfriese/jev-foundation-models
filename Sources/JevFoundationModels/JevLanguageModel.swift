import Foundation
import FoundationModels
import UniformTypeIdentifiers

/// An Apple Foundation Models provider for TypeSafe AI's Jev System One decision models.
public struct JevLanguageModel: LanguageModel, Sendable {
    public struct Configuration: Hashable, Sendable {
        public var apiKey: String
        public var modelID: String
        public var endpoint: URL

        public init(
            apiKey: String,
            modelID: String = "jev-latest",
            endpoint: URL = URL(string: "https://api.typesafe.ai/v1/systemone")!
        ) {
            self.apiKey = apiKey
            self.modelID = modelID
            self.endpoint = endpoint
        }
    }

    public typealias Executor = JevExecutor

    public var executorConfiguration: Configuration

    public var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities(supportsTools: false, supportsStructuredOutput: true)
    }

    public init(
        apiKey: String,
        modelID: String = "jev-latest",
        endpoint: URL = URL(string: "https://api.typesafe.ai/v1/systemone")!
    ) {
        self.executorConfiguration = Configuration(apiKey: apiKey, modelID: modelID, endpoint: endpoint)
    }

    public func supportsDataAttachmentType(_ type: UTType) async throws -> Bool {
        false
    }

    public func supportsDataEntryType(_ type: UTType) async throws -> Bool {
        false
    }
}
