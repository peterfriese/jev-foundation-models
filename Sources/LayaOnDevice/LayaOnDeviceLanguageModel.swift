import Foundation
import FoundationModels
import UniformTypeIdentifiers
@_exported import SystemOneCore

/// An Apple Foundation Models provider for on-device Laya decision models running locally via Core ML.
public struct LayaOnDeviceLanguageModel: LanguageModel, Sendable {
    public struct Configuration: Hashable, Sendable {
        public var backend: AnySystemOneBackend
        public var modelID: String

        public init(backend: AnySystemOneBackend, modelID: String = "laya-ondevice") {
            self.backend = backend
            self.modelID = modelID
        }

        public init(engine: LayaCoreMLEngine, modelID: String = "laya-ondevice") {
            let onDeviceBackend = LayaOnDeviceBackend(engine: engine)
            self.backend = AnySystemOneBackend(onDeviceBackend)
            self.modelID = modelID
        }
    }

    public typealias Executor = LayaOnDeviceExecutor

    public var executorConfiguration: Configuration

    public var capabilities: LanguageModelCapabilities {
        LanguageModelCapabilities([.guidedGeneration])
    }

    public init(engine: LayaCoreMLEngine, modelID: String = "laya-ondevice") {
        let backend = AnySystemOneBackend(LayaOnDeviceBackend(engine: engine))
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

/// An executor bridging `LanguageModelSession` requests to an on-device Laya Core ML engine.
public final class LayaOnDeviceExecutor: LanguageModelExecutor, Sendable {
    public typealias Model = LayaOnDeviceLanguageModel
    public typealias Configuration = LayaOnDeviceLanguageModel.Configuration

    public let configuration: Configuration
    private let underlyingExecutor: SystemOneExecutor

    public init(configuration: Configuration) throws {
        self.configuration = configuration
        let coreConfig = SystemOneLanguageModel.Configuration(
            backend: configuration.backend,
            modelID: configuration.modelID
        )
        self.underlyingExecutor = try SystemOneExecutor(configuration: coreConfig)
    }

    public func prewarm(model: LayaOnDeviceLanguageModel, transcript: Transcript) {
        // Prewarm Neural Engine compilation pipelines if needed
    }

    public func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: LayaOnDeviceLanguageModel,
        streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws {
        let coreModel = SystemOneLanguageModel(
            backend: configuration.backend,
            modelID: configuration.modelID
        )
        try await underlyingExecutor.respond(to: request, model: coreModel, streamingInto: channel)
    }

    public func extractState(from transcript: Transcript) -> String {
        underlyingExecutor.extractState(from: transcript)
    }
}
