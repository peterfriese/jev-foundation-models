import Foundation
import FoundationModels
import UniformTypeIdentifiers

/// An Apple Foundation Models provider for TypeSafe AI's Jev System One decision models.
public struct JevLanguageModel: LanguageModel, Sendable {
    public struct Configuration: Hashable, Sendable {
        public var apiKey: String?
        public var modelID: String
        public var endpoint: URL
        public var transport: AnyJevTransport
        public var retryPolicy: RetryPolicy

        public init(
            apiKey: String? = nil,
            modelID: String = "jev-latest",
            endpoint: URL = URL(string: "https://api.typesafe.ai/v1/systemone")!,
            transport: AnyJevTransport? = nil,
            retryPolicy: RetryPolicy = .default
        ) {
            self.apiKey = apiKey
            self.modelID = modelID
            self.endpoint = endpoint
            self.retryPolicy = retryPolicy
            self.transport = transport ?? AnyJevTransport(URLSessionTransport(retryPolicy: retryPolicy))
        }
    }

    public typealias Executor = JevExecutor

    public var executorConfiguration: Configuration

    public var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities([.guidedGeneration])
    }

    public init(
        apiKey: String? = nil,
        modelID: String = "jev-latest",
        endpoint: URL = URL(string: "https://api.typesafe.ai/v1/systemone")!,
        transport: (any JevTransport)? = nil,
        retryPolicy: RetryPolicy = .default
    ) {
        let resolvedTransport = transport.map { AnyJevTransport($0) }
            ?? AnyJevTransport(URLSessionTransport(retryPolicy: retryPolicy))
        self.executorConfiguration = Configuration(
            apiKey: apiKey,
            modelID: modelID,
            endpoint: endpoint,
            transport: resolvedTransport,
            retryPolicy: retryPolicy
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
