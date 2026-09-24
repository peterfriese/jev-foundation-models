import Foundation
import SystemOneCore

/// A local, on-device `SystemOneBackend` backed by `LayaCoreMLEngine`.
public struct LayaOnDeviceBackend: SystemOneBackend, Sendable {
    public let engine: LayaCoreMLEngine

    public init(engine: LayaCoreMLEngine) {
        self.engine = engine
    }

    public func evaluate(request: SystemOneRequest) async throws -> SystemOneResponse {
        try await engine.predict(request: request)
    }
}
