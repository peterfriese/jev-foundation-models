import SwiftUI
import AppCore
import FactoryKit

public struct HeaderView: View {
    @Injected(\.greetingService) private var greetingService
    public var title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(greetingService.getGreeting(for: "Developer"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    let _ = Container.shared.greetingService.register { MockGreetingService() }
    HeaderView(title: "MailTriageApp")
}
