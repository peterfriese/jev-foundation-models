import SwiftUI
import AppCore
import FactoryKit

public struct MailSplitView: View {
    @Injected(\.mailStore) private var store
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            MailSidebarView(store: store)
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
                #endif
        } content: {
            MailListView(store: store)
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 480)
                #endif
        } detail: {
            MailDetailView(store: store)
                #if os(macOS)
                .frame(minWidth: 460)
                #endif
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    let _ = Container.shared.mailStore.register {
        MailStore(emails: InboxData.sampleEmails)
    }
    MailSplitView()
}
