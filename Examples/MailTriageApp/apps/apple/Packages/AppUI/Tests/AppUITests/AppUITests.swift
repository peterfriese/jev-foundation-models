import Testing
import SwiftUI
import AppCore
import FactoryKit
@testable import AppUI

@Suite("AppUI Tests")
@MainActor
struct AppUITests {
    @Test("Header view initialization")
    func testHeaderView() {
        let view = HeaderView(title: "Test")
        #expect(view.title == "Test")
    }

    @Test("MailRowView renders email correctly")
    func testMailRowView() {
        let email = InboxData.sampleEmails[0]
        let rowView = MailRowView(email: email)
        #expect(rowView.email.id == email.id)
        #expect(rowView.email.sender == email.sender)
    }

    @Test("MailSidebarView initialization with store")
    func testMailSidebarView() {
        let store = MailStore(emails: InboxData.sampleEmails)
        let sidebar = MailSidebarView(store: store)
        #expect(sidebar.store.selectedMailbox == .inbox)
    }

    @Test("MailListView initialization with store")
    func testMailListView() {
        let store = MailStore(emails: InboxData.sampleEmails)
        let listView = MailListView(store: store)
        #expect(listView.store.filteredEmails.count > 0)
    }

    @Test("MailDetailView empty state and selected state")
    func testMailDetailView() {
        let store = MailStore(emails: InboxData.sampleEmails)
        let detailView = MailDetailView(store: store)
        #expect(detailView.store.selectedEmail != nil)

        store.selectedEmailID = nil
        #expect(detailView.store.selectedEmail == nil)
    }

    @Test("MailDetailView with non-inbox email")
    func testMailDetailViewNonInbox() {
        let store = MailStore(emails: InboxData.sampleEmails, selectedMailbox: .archive)
        let detailView = MailDetailView(store: store)
        #expect(detailView.store.selectedEmail?.mailbox == .archive)
    }

    @Test("MailSplitView initialization with Factory")
    func testMailSplitView() {
        Container.shared.mailStore.register {
            MailStore(emails: InboxData.sampleEmails)
        }
        let splitView = MailSplitView()
        #expect(type(of: splitView) == MailSplitView.self)
    }
}
