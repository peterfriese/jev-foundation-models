import Foundation
import Testing
@testable import AppCore

@Suite("AppCore Models and Dataset Tests")
struct AppCoreModelsTests {
    @Test("InboxData generates exactly 500 emails")
    func testSampleEmailsCount() {
        let emails = InboxData.sampleEmails
        #expect(emails.count == 500)
    }

    @Test("InboxData unread count is approximately 180")
    func testSampleEmailsUnreadCount() {
        let emails = InboxData.sampleEmails
        let unreadCount = emails.filter(\.isUnread).count
        // Expect close to 180 unread
        #expect(unreadCount >= 170 && unreadCount <= 190)
    }

    @Test("InboxData contains diverse enterprise categories")
    func testEnterpriseCategoriesPresent() {
        let emails = InboxData.sampleEmails
        let categories = Set(emails.compactMap(\.category))
        #expect(categories.contains(.work))
        #expect(categories.contains(.securityAlerts))
        #expect(categories.contains(.billing))
        #expect(categories.contains(.meetings))
        #expect(categories.contains(.newsletters))
        #expect(categories.contains(.quarantine))
    }

    @Test("Email initials extraction works correctly")
    func testEmailSenderInitials() {
        let email1 = Email(
            sender: "Jeff Dean",
            senderEmail: "jeff@google.com",
            subject: "Test",
            previewSnippet: "Snippet",
            body: "Body",
            date: Date()
        )
        #expect(email1.senderInitials == "JD")

        let email2 = Email(
            sender: "Kelsey",
            senderEmail: "kelsey@minimalist.dev",
            subject: "Test",
            previewSnippet: "Snippet",
            body: "Body",
            date: Date()
        )
        #expect(email2.senderInitials == "KE")
    }

    @Test("Mailbox properties are configured properly")
    func testMailboxProperties() {
        #expect(Mailbox.inbox.isFavorite == true)
        #expect(Mailbox.vips.isFavorite == true)
        #expect(Mailbox.flagged.isFavorite == true)
        #expect(Mailbox.drafts.isFavorite == true)
        #expect(Mailbox.sent.isFavorite == true)

        #expect(Mailbox.securityAlerts.isCategory == true)
        #expect(Mailbox.billing.isCategory == true)
        #expect(Mailbox.work.isCategory == true)
        #expect(Mailbox.meetings.isCategory == true)
        #expect(Mailbox.newsletters.isCategory == true)
        #expect(Mailbox.quarantine.isCategory == true)
        #expect(Mailbox.archive.isCategory == true)

        #expect(Mailbox.favorites.count == 5)
        #expect(Mailbox.categories.count == 7)
    }
}

@Suite("MailStore State and Action Tests")
@MainActor
struct MailStoreTests {
    @Test("MailStore initial state loads emails and calculates counts")
    func testInitialState() {
        let store = MailStore()
        #expect(store.totalEmailCount == 500)
        #expect(store.selectedMailbox == .inbox)
        #expect(store.selectedEmailID != nil)
        #expect(store.totalCountForCurrentMailbox > 0)
        #expect(store.unreadCountForCurrentMailbox > 0)
    }

    @Test("MailStore filtering by unread only")
    func testUnreadFilter() {
        let store = MailStore()
        let initialCount = store.filteredEmails.count
        store.unreadOnly = true
        let unreadCount = store.filteredEmails.count
        #expect(unreadCount <= initialCount)
        let allUnread = store.filteredEmails.allSatisfy { $0.isUnread }
        #expect(allUnread)
    }

    @Test("MailStore search filtering")
    func testSearchFilter() {
        let store = MailStore()
        store.searchText = "Jeff Dean"
        let filtered = store.filteredEmails
        #expect(filtered.allSatisfy { email in
            email.sender.localizedCaseInsensitiveContains("Jeff Dean") ||
            email.subject.localizedCaseInsensitiveContains("Jeff Dean") ||
            email.body.localizedCaseInsensitiveContains("Jeff Dean")
        })
    }

    @Test("MailStore toggles unread state")
    func testToggleUnread() {
        let store = MailStore()
        guard let first = store.filteredEmails.first else {
            Issue.record("No email found")
            return
        }
        let wasUnread = first.isUnread
        store.toggleUnread(for: first.id)
        let updated = store.emails.first(where: { $0.id == first.id })
        #expect(updated?.isUnread == !wasUnread)
    }

    @Test("MailStore toggles flag")
    func testToggleFlag() {
        let store = MailStore()
        guard let first = store.filteredEmails.first else {
            Issue.record("No email found")
            return
        }
        let wasFlagged = first.isFlagged
        store.toggleFlag(for: first.id)
        let updated = store.emails.first(where: { $0.id == first.id })
        #expect(updated?.isFlagged == !wasFlagged)
    }

    @Test("MailStore moves email to another mailbox")
    func testMoveToMailbox() {
        let store = MailStore()
        guard let first = store.filteredEmails.first else {
            Issue.record("No email found")
            return
        }
        store.moveToMailbox(first.id, mailbox: .archive)
        let updated = store.emails.first(where: { $0.id == first.id })
        #expect(updated?.mailbox == .archive)
    }

    @Test("MailStore moves email back to inbox from archive")
    func testMoveToInboxFromArchive() {
        let store = MailStore()
        store.selectMailbox(.archive)
        guard let first = store.filteredEmails.first else {
            Issue.record("No archived email found")
            return
        }
        #expect(first.mailbox == .archive)
        store.selectedEmailID = first.id

        store.moveToInbox(first.id)

        let updated = store.emails.first(where: { $0.id == first.id })
        #expect(updated?.mailbox == .inbox)
        #expect(store.selectedEmailID != first.id)
        #expect(store.filteredEmails.contains(where: { $0.id == first.id }) == false)
    }

    @Test("MailStore moves email back to inbox from quarantine")
    func testMoveToInboxFromQuarantine() {
        let store = MailStore()
        store.selectMailbox(.quarantine)
        guard let first = store.filteredEmails.first else {
            Issue.record("No quarantined email found")
            return
        }
        store.selectedEmailID = first.id

        store.moveToInbox(first.id)

        let updated = store.emails.first(where: { $0.id == first.id })
        #expect(updated?.mailbox == .inbox)
        #expect(updated?.category != .quarantine)
        #expect(store.selectedEmailID != first.id)
        #expect(store.filteredEmails.contains(where: { $0.id == first.id }) == false)
    }

    @Test("MailStore moveToMailbox transitions selectedEmailID when email leaves current mailbox")
    func testMoveToMailboxTransitionsSelection() {
        let store = MailStore()
        store.selectMailbox(.inbox)
        guard let first = store.filteredEmails.first else {
            Issue.record("No inbox email found")
            return
        }
        store.selectedEmailID = first.id

        store.moveToMailbox(first.id, mailbox: .work)

        let updated = store.emails.first(where: { $0.id == first.id })
        #expect(updated?.mailbox == .work)
        #expect(store.selectedEmailID != first.id)
    }

    @Test("MailStore archives email")
    func testArchiveEmail() {
        let store = MailStore()
        guard let first = store.filteredEmails.first else {
            Issue.record("No email found")
            return
        }
        store.archiveEmail(first.id)
        let updated = store.emails.first(where: { $0.id == first.id })
        #expect(updated?.mailbox == .archive)
    }

    @Test("MailStore deletes email")
    func testDeleteEmail() {
        let store = MailStore()
        let countBefore = store.totalEmailCount
        guard let first = store.filteredEmails.first else {
            Issue.record("No email found")
            return
        }
        store.deleteEmail(first.id)
        #expect(store.totalEmailCount == countBefore - 1)
        #expect(store.emails.contains(where: { $0.id == first.id }) == false)
    }

    @Test("MailStore marks all as read")
    func testMarkAllAsRead() {
        let store = MailStore()
        #expect(store.unreadCountForCurrentMailbox > 0)
        store.markAllAsRead()
        #expect(store.unreadCountForCurrentMailbox == 0)
    }
}
