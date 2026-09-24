import Foundation
import FoundationModels
import UniformTypeIdentifiers

/// An Apple Foundation Models provider for System One decision models.
public struct SystemOneLanguageModel: LanguageModel, Sendable {
    public struct Configuration: Hashable, Sendable {
        public var backend: AnySystemOneBackend
        public var modelID: String

        public init(
            backend: AnySystemOneBackend,
            modelID: String = "systemone-default"
        ) {
            self.backend = backend
            self.modelID = modelID
        }

        public init(
            backend: some SystemOneBackend,
            modelID: String = "systemone-default"
        ) {
            self.backend = AnySystemOneBackend(backend)
            self.modelID = modelID
        }
    }

    public typealias Executor = SystemOneExecutor

    public var executorConfiguration: Configuration

    public var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities([.guidedGeneration])
    }

    public init(
        backend: some SystemOneBackend,
        modelID: String = "systemone-default"
    ) {
        self.executorConfiguration = Configuration(backend: AnySystemOneBackend(backend), modelID: modelID)
    }

    public init(
        backend: AnySystemOneBackend,
        modelID: String = "systemone-default"
    ) {
        self.executorConfiguration = Configuration(backend: backend, modelID: modelID)
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
