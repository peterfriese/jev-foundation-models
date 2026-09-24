import Foundation
import Observation

@Observable
@MainActor
public final class MailStore {
    public var emails: [Email]
    public var selectedMailbox: Mailbox {
        didSet {
            // Keep selection valid or clear if selected email is not in current view
            if let selectedEmailID, !filteredEmails.contains(where: { $0.id == selectedEmailID }) {
                self.selectedEmailID = filteredEmails.first?.id
            }
        }
    }
    public var selectedEmailID: UUID?
    public var searchText: String = ""
    public var unreadOnly: Bool = false

    public init(emails: [Email] = InboxData.sampleEmails, selectedMailbox: Mailbox = .inbox) {
        self.emails = emails
        self.selectedMailbox = selectedMailbox
        self.selectedEmailID = emails.first(where: { $0.mailbox == selectedMailbox })?.id
    }

    // MARK: - Computed Properties

    public var selectedEmail: Email? {
        guard let selectedEmailID else { return nil }
        return emails.first(where: { $0.id == selectedEmailID })
    }

    public var totalEmailCount: Int {
        emails.count
    }

    public var filteredEmails: [Email] {
        let base = emails.filter { email in
            matchesMailbox(email: email, mailbox: selectedMailbox)
        }

        let unreadFiltered = unreadOnly ? base.filter(\.isUnread) : base

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return unreadFiltered
        }

        return unreadFiltered.filter { email in
            email.sender.localizedCaseInsensitiveContains(query) ||
            email.senderEmail.localizedCaseInsensitiveContains(query) ||
            email.subject.localizedCaseInsensitiveContains(query) ||
            email.previewSnippet.localizedCaseInsensitiveContains(query) ||
            email.body.localizedCaseInsensitiveContains(query)
        }
    }

    public var totalCountForCurrentMailbox: Int {
        totalCount(for: selectedMailbox)
    }

    public var unreadCountForCurrentMailbox: Int {
        unreadCount(for: selectedMailbox)
    }

    public func totalCount(for mailbox: Mailbox) -> Int {
        emails.filter { matchesMailbox(email: $0, mailbox: mailbox) }.count
    }

    public func unreadCount(for mailbox: Mailbox) -> Int {
        emails.filter { matchesMailbox(email: $0, mailbox: mailbox) && $0.isUnread }.count
    }

    // MARK: - Mailbox Matching Logic

    private func matchesMailbox(email: Email, mailbox: Mailbox) -> Bool {
        switch mailbox {
        case .inbox:
            return email.mailbox == .inbox
        case .vips:
            return email.isVIP && email.mailbox != .archive && email.mailbox != .quarantine
        case .flagged:
            return email.isFlagged && email.mailbox != .archive && email.mailbox != .quarantine
        case .drafts:
            return email.mailbox == .drafts
        case .sent:
            return email.mailbox == .sent
        case .securityAlerts:
            return email.mailbox == .securityAlerts || (email.mailbox == .inbox && email.category == .securityAlerts)
        case .billing:
            return email.mailbox == .billing || (email.mailbox == .inbox && email.category == .billing)
        case .work:
            return email.mailbox == .work || (email.mailbox == .inbox && email.category == .work)
        case .meetings:
            return email.mailbox == .meetings || (email.mailbox == .inbox && email.category == .meetings)
        case .newsletters:
            return email.mailbox == .newsletters || (email.mailbox == .inbox && email.category == .newsletters)
        case .quarantine:
            return email.mailbox == .quarantine || (email.mailbox == .inbox && email.category == .quarantine)
        case .archive:
            return email.mailbox == .archive
        }
    }

    // MARK: - Actions

    public func selectMailbox(_ mailbox: Mailbox) {
        selectedMailbox = mailbox
    }

    public func selectEmail(_ email: Email?) {
        selectedEmailID = email?.id
        if let email, email.isUnread {
            markAsRead(email.id)
        }
    }

    public func toggleUnread(for id: UUID) {
        guard let index = emails.firstIndex(where: { $0.id == id }) else { return }
        emails[index].isUnread.toggle()
    }

    public func markAsRead(_ id: UUID) {
        guard let index = emails.firstIndex(where: { $0.id == id }) else { return }
        emails[index].isUnread = false
    }

    public func markAllAsRead() {
        for index in emails.indices {
            if matchesMailbox(email: emails[index], mailbox: selectedMailbox) {
                emails[index].isUnread = false
            }
        }
    }

    public func toggleFlag(for id: UUID) {
        guard let index = emails.firstIndex(where: { $0.id == id }) else { return }
        emails[index].isFlagged.toggle()
    }

    public func moveToMailbox(_ id: UUID, mailbox: Mailbox) {
        guard let index = emails.firstIndex(where: { $0.id == id }) else { return }
        emails[index].mailbox = mailbox
        if mailbox == .inbox && emails[index].category == .quarantine {
            emails[index].category = nil
        }
        if selectedMailbox != mailbox && selectedEmailID == id {
            if !matchesMailbox(email: emails[index], mailbox: selectedMailbox) {
                selectedEmailID = filteredEmails.first(where: { $0.id != id })?.id
            }
        }
    }

    public func moveToInbox(_ id: UUID) {
        moveToMailbox(id, mailbox: .inbox)
        if selectedMailbox != .inbox && selectedEmailID == id {
            selectedEmailID = filteredEmails.first(where: { $0.id != id })?.id
        }
    }

    public func archiveEmail(_ id: UUID) {
        moveToMailbox(id, mailbox: .archive)
        if selectedEmailID == id {
            selectedEmailID = filteredEmails.first(where: { $0.id != id })?.id
        }
    }

    public func deleteEmail(_ id: UUID) {
        guard let index = emails.firstIndex(where: { $0.id == id }) else { return }
        emails.remove(at: index)
        if selectedEmailID == id {
            selectedEmailID = filteredEmails.first?.id
        }
    }

    public func resetData() {
        self.emails = InboxData.sampleEmails
        self.selectedMailbox = .inbox
        self.selectedEmailID = emails.first(where: { $0.mailbox == .inbox })?.id
        self.searchText = ""
        self.unreadOnly = false
    }
}
