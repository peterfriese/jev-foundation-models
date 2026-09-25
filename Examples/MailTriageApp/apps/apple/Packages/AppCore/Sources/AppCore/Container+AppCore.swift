import Foundation
@_exported import FactoryKit

extension Container {
    public var keychainService: Factory<KeychainServiceProtocol> {
        self { KeychainService() }.singleton
    }

    public var backendConfigurationStore: Factory<BackendConfigurationStore> {
        self { BackendConfigurationStore() }.singleton
    }

    public var coreMLModelManager: Factory<CoreMLModelManager> {
        self { CoreMLModelManager() }.singleton
    }

    public var backendHealthProbeService: Factory<BackendHealthProbeServiceProtocol> {
        self { BackendHealthProbeService() }.singleton
    }

    public var greetingService: Factory<GreetingServiceProtocol> {
        self { GreetingService() }.singleton
    }

    public var triageEngine: Factory<TriageEngineProtocol> {
        self { TriageEngine() }.singleton
    }

    public var benchmarkTruthStore: Factory<BenchmarkTruthStoreProtocol> {
        self { BenchmarkTruthStore() }.singleton
    }

    @MainActor
    public var mailStore: Factory<MailStore> {
        self { MailStore() }.singleton
    }
}

public protocol GreetingServiceProtocol: Sendable {
    func getGreeting(for name: String) -> String
}

public final class GreetingService: GreetingServiceProtocol {
    public init() {}
    public func getGreeting(for name: String) -> String {
        return "Hello, \(name)! Welcome to MailTriageApp (Pure Native Swift 6 & SwiftUI)."
    }
}

public final class MockGreetingService: GreetingServiceProtocol {
    public init() {}
    public func getGreeting(for name: String) -> String {
        return "Mock Greeting for Preview"
    }
}
