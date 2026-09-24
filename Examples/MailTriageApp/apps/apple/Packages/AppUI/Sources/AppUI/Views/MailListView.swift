import SwiftUI
import AppCore

public struct MailListView: View {
    @Bindable public var store: MailStore

    public init(store: MailStore) {
        self.store = store
    }

    public var body: some View {
        List(selection: $store.selectedEmailID) {
            ForEach(store.filteredEmails) { email in
                MailRowView(email: email)
                    .tag(email.id)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                store.toggleUnread(for: email.id)
                            }
                        } label: {
                            Label(
                                email.isUnread ? "Mark as Read" : "Mark as Unread",
                                systemImage: email.isUnread ? "envelope.open" : "envelope.badge"
                            )
                        }
                        .tint(.blue)

                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                store.toggleFlag(for: email.id)
                            }
                        } label: {
                            Label(
                                email.isFlagged ? "Unflag" : "Flag",
                                systemImage: email.isFlagged ? "flag.slash" : "flag.fill"
                            )
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if store.selectedMailbox != .inbox {
                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    store.moveToInbox(email.id)
                                }
                            } label: {
                                Label("Move to Inbox", systemImage: "tray.and.arrow.down")
                            }
                            .tint(.blue)
                        }

                        Button(role: .destructive) {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                store.archiveEmail(email.id)
                            }
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.gray)
                    }
                    .contextMenu {
                        if email.mailbox != .inbox || store.selectedMailbox != .inbox {
                            Button("Move to Inbox", systemImage: "tray.and.arrow.down") {
                                withAnimation {
                                    store.moveToInbox(email.id)
                                }
                            }
                        }

                        Button {
                            store.toggleUnread(for: email.id)
                        } label: {
                            Label(
                                email.isUnread ? "Mark as Read" : "Mark as Unread",
                                systemImage: email.isUnread ? "envelope.open" : "envelope.badge"
                            )
                        }

                        Button {
                            store.toggleFlag(for: email.id)
                        } label: {
                            Label(
                                email.isFlagged ? "Unflag" : "Flag",
                                systemImage: email.isFlagged ? "flag.slash" : "flag.fill"
                            )
                        }

                        Divider()

                        Menu("Move to...") {
                            Button("Inbox", systemImage: "tray") {
                                withAnimation {
                                    store.moveToInbox(email.id)
                                }
                            }

                            Divider()

                            ForEach(Mailbox.categories) { mb in
                                Button(mb.title) {
                                    withAnimation {
                                        store.moveToMailbox(email.id, mailbox: mb)
                                    }
                                }
                            }
                        }

                        Button(role: .destructive) {
                            store.archiveEmail(email.id)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }

                        Button(role: .destructive) {
                            store.deleteEmail(email.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .navigationTitle(store.selectedMailbox.title)
        #if os(macOS)
        .navigationSubtitle("\(store.totalCount(for: store.selectedMailbox)) messages, \(store.unreadCount(for: store.selectedMailbox)) unread")
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search")
        #else
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $store.searchText, prompt: "Search \(store.selectedMailbox.title)")
        #endif
        .overlay {
            if store.filteredEmails.isEmpty {
                ContentUnavailableView {
                    Label("No Messages", systemImage: "tray")
                } description: {
                    if !store.searchText.isEmpty {
                        Text("No emails matching \"\(store.searchText)\" in \(store.selectedMailbox.title).")
                    } else if store.unreadOnly {
                        Text("No unread emails in \(store.selectedMailbox.title).")
                    } else {
                        Text("This mailbox is currently empty.")
                    }
                }
            }
        }
        .toolbar {
            #if os(macOS)
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        store.unreadOnly.toggle()
                    }
                } label: {
                    Image(systemName: store.unreadOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .help(store.unreadOnly ? "Show All Messages" : "Filter by Unread Only")

                Menu {
                    Toggle("Filter by Unread Only", isOn: $store.unreadOnly)
                    Divider()
                    Button("Mark All as Read") {
                        withAnimation {
                            store.markAllAsRead()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("More Actions")
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        store.unreadOnly.toggle()
                    }
                } label: {
                    Image(systemName: store.unreadOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .help(store.unreadOnly ? "Show All Messages" : "Filter by Unread Only")
            }
            #endif
        }
        #if os(iOS)
        .safeAreaInset(edge: .top) {
            filterStatusHeader
        }
        #endif
    }

    #if os(iOS)
    private var filterStatusHeader: some View {
        HStack {
            Text("\(store.totalCountForCurrentMailbox) messages, \(store.unreadCountForCurrentMailbox) unread")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            if store.unreadOnly {
                Text("Filtered: Unread Only")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }
    #endif
}

#Preview {
    let store = MailStore(emails: InboxData.sampleEmails)
    NavigationStack {
        MailListView(store: store)
    }
}
