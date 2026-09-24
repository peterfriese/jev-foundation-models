import SwiftUI
import AppCore
import AppUI

@main
struct MailTriageAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowToolbarStyle(.unified(showsTitle: false))
        #endif
    }
}
