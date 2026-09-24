import Foundation
@_exported import FactoryKit

extension Container {
    public var greetingService: Factory<GreetingServiceProtocol> {
        self { GreetingService() }.singleton
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
