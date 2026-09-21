import Foundation
import FoundationModels
import UniformTypeIdentifiers

/// An Apple Foundation Models provider for TypeSafe AI's Jev System One decision models.
public struct JevLanguageModel: LanguageModel, Sendable {
    public struct Configuration: Hashable, Sendable {
        public var apiKey: String
        public var modelID: String
        public var endpoint: URL
        public var transport: AnyJevTransport

        public init(
            apiKey: String,
            modelID: String = "jev-latest",
            endpoint: URL = URL(string: "https://api.typesafe.ai/v1/systemone")!,
            transport: AnyJevTransport = AnyJevTransport(URLSessionTransport())
        ) {
            self.apiKey = apiKey
            self.modelID = modelID
            self.endpoint = endpoint
            self.transport = transport
        }
    }

    public typealias Executor = JevExecutor

    public var executorConfiguration: Configuration

    public var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities([.guidedGeneration])
    }

    public init(
        apiKey: String,
        modelID: String = "jev-latest",
        endpoint: URL = URL(string: "https://api.typesafe.ai/v1/systemone")!,
        transport: (any JevTransport)? = nil
    ) {
        let resolvedTransport = transport.map { AnyJevTransport($0) } ?? AnyJevTransport(URLSessionTransport())
        self.executorConfiguration = Configuration(
            apiKey: apiKey,
            modelID: modelID,
            endpoint: endpoint,
            transport: resolvedTransport
        )
    }

    public init(configuration: Configuration) {
        self.executorConfiguration = configuration
    }

    public func supportsDataAttachmentType(_ type: UTType) async throws -> Bool {
        false
    }

    public func supportsDataEntryType(_ type: UTType) async throws -> Bool {
        false
    }
}
