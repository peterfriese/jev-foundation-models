import SwiftUI
import AppCore

public struct MailDetailView: View {
    @Bindable public var store: MailStore
    @State private var showingComposeSheet = false

    public init(store: MailStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            if let email = store.selectedEmail {
                emailContentView(email)
            } else {
                ContentUnavailableView(
                    "No Message Selected",
                    systemImage: "envelope",
                    description: Text("Choose an email from the message list to view its contents.")
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Compose
                Button {
                    showingComposeSheet = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Message")

                // Reply Actions
                Button {
                    // Reply
                } label: {
                    Image(systemName: "arrowshape.turn.up.left")
                }
                .disabled(store.selectedEmail == nil)
                .help("Reply")

                Button {
                    // Reply All
                } label: {
                    Image(systemName: "arrowshape.turn.up.left.2")
                }
                .disabled(store.selectedEmail == nil)
                .help("Reply All")

                Button {
                    // Forward
                } label: {
                    Image(systemName: "arrowshape.turn.up.right")
                }
                .disabled(store.selectedEmail == nil)
                .help("Forward")

                // Management Actions
                if let email = store.selectedEmail, email.mailbox != .inbox {
                    Button {
                        withAnimation {
                            store.moveToInbox(email.id)
                        }
                    } label: {
                        Image(systemName: "tray.and.arrow.down")
                    }
                    .help("Move to Inbox")
                }

                Button {
                    if let id = store.selectedEmailID {
                        withAnimation {
                            store.archiveEmail(id)
                        }
                    }
                } label: {
                    Image(systemName: "archivebox")
                }
                .disabled(store.selectedEmail == nil)
                .help("Archive Message")

                Button(role: .destructive) {
                    if let id = store.selectedEmailID {
                        withAnimation {
                            store.deleteEmail(id)
                        }
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(store.selectedEmail == nil)
                .help("Delete Message")

                Menu {
                    Button {
                        if let id = store.selectedEmailID {
                            withAnimation {
                                store.moveToInbox(id)
                            }
                        }
                    } label: {
                        Label("Inbox", systemImage: "tray")
                    }

                    Divider()

                    ForEach(Mailbox.categories) { mb in
                        Button(mb.title) {
                            if let id = store.selectedEmailID {
                                withAnimation {
                                    store.moveToMailbox(id, mailbox: mb)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "folder")
                }
                .disabled(store.selectedEmail == nil)
                .help("Move to Folder")

                Button {
                    if let id = store.selectedEmailID {
                        withAnimation {
                            store.toggleFlag(for: id)
                        }
                    }
                } label: {
                    let isFlagged = store.selectedEmail?.isFlagged ?? false
                    Image(systemName: isFlagged ? "flag.fill" : "flag")
                        .foregroundStyle(isFlagged ? .orange : .primary)
                }
                .disabled(store.selectedEmail == nil)
                .help(store.selectedEmail?.isFlagged == true ? "Remove Flag" : "Flag Message")

                Button {
                    if let id = store.selectedEmailID {
                        withAnimation {
                            store.toggleUnread(for: id)
                        }
                    }
                } label: {
                    let isUnread = store.selectedEmail?.isUnread ?? false
                    Image(systemName: isUnread ? "envelope.open" : "envelope.badge")
                }
                .disabled(store.selectedEmail == nil)
                .help(store.selectedEmail?.isUnread == true ? "Mark as Read" : "Mark as Unread")
            }
        }
        .sheet(isPresented: $showingComposeSheet) {
            ComposeMessageSheet()
        }
    }

    @ViewBuilder
    private func emailContentView(_ email: Email) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Subject header
                Text(email.subject)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                // Sender & Metadata row
                HStack(alignment: .center, spacing: 14) {
                    // Avatar monogram
                    ZStack {
                        Circle()
                            .fill(avatarColor(for: email.sender))
                            .frame(width: 44, height: 44)
                        Text(email.senderInitials)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(email.sender)
                                .font(.headline)
                            if email.isVIP {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        Text(email.senderEmail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("To: \(email.recipient)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(email.date, format: .dateTime.month().day().year().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if email.isFlagged {
                            Label("Flagged", systemImage: "flag.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // Triage Decision Banner (if triage metadata present or not in inbox)
                if email.category != nil || email.urgencyScore != nil || email.suggestedAction != nil || email.mailbox != .inbox {
                    triageBanner(for: email)
                }

                Divider()

                // Email Body
                Text(email.body)
                    .font(.body)
                    .lineSpacing(5)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func triageBanner(for email: Email) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let category = email.category {
                    Label(category.displayName, systemImage: category.iconName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                } else if email.mailbox != .inbox {
                    Label(email.mailbox.title, systemImage: email.mailbox.iconName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }

                if let score = email.urgencyScore {
                    let (label, color): (String, Color) = {
                        switch score {
                        case 3: return ("P0 Critical", .red)
                        case 2: return ("P1 High", .orange)
                        case 1: return ("P2 Medium", .blue)
                        default: return ("P3 Low", .secondary)
                        }
                    }()
                    Text(label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.12), in: Capsule())
                }

                Spacer()

                if email.mailbox != .inbox || email.category == .quarantine {
                    Button {
                        withAnimation {
                            store.moveToInbox(email.id)
                        }
                    } label: {
                        Label("Move to Inbox", systemImage: "tray.and.arrow.down")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if let action = email.suggestedAction {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)
                        .font(.caption)
                    Text("Suggested: \(action)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .indigo, .teal, .green, .orange, .pink]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}

private struct ComposeMessageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var toText = ""
    @State private var subjectText = ""
    @State private var bodyText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("To:", text: $toText)
                    TextField("Subject:", text: $subjectText)
                }
                Section {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 180)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Message")
            #if os(macOS)
            .frame(minWidth: 480, minHeight: 340)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        dismiss()
                    }
                    .disabled(toText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    let store = MailStore(emails: InboxData.sampleEmails)
    MailDetailView(store: store)
}
