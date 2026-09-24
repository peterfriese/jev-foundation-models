import Foundation

/// A pluggable backend responsible for executing System One decision evaluations.
public protocol SystemOneBackend: Sendable {
    /// Dispatches a `SystemOneRequest` and returns the evaluated `SystemOneResponse`.
    func evaluate(request: SystemOneRequest) async throws -> SystemOneResponse
}

/// A type-erased wrapper for any `SystemOneBackend` conforming to `Hashable` and `Sendable`.
public struct AnySystemOneBackend: SystemOneBackend, Hashable, Sendable {
    public let id: UUID
    private let _evaluate: @Sendable (SystemOneRequest) async throws -> SystemOneResponse

    public init(_ backend: some SystemOneBackend, id: UUID = UUID()) {
        self.id = id
        self._evaluate = { try await backend.evaluate(request: $0) }
    }

    public init(id: UUID = UUID(), handler: @escaping @Sendable (SystemOneRequest) async throws -> SystemOneResponse) {
        self.id = id
        self._evaluate = handler
    }

    public static func == (lhs: AnySystemOneBackend, rhs: AnySystemOneBackend) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public func evaluate(request: SystemOneRequest) async throws -> SystemOneResponse {
        try await _evaluate(request)
    }
}
