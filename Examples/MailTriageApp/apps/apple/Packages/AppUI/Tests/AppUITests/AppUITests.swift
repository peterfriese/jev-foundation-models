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

    @Test("ToolbarBackendSelector initializes and reflects store state")
    func testToolbarBackendSelector() {
        let store = MailStore(emails: InboxData.sampleEmails)
        store.selectedBackend = .hostedVPC
        let selector = ToolbarBackendSelector(store: store)
        #expect(selector.store.selectedBackend == .hostedVPC)
    }

    @Test("DecisionActionBarView initializes for untriaged and triaged email")
    func testDecisionActionBarView() {
        let store = MailStore(emails: InboxData.sampleEmails)
        let sample = InboxData.sampleEmails[0]

        // Untriaged
        let untriagedBar = DecisionActionBarView(store: store, email: sample)
        #expect(untriagedBar.email.id == sample.id)

        // Triaged
        let decision = EmailTriageDecision(
            requiresAction: true,
            category: .quarantine,
            urgencyScore: 0,
            suggestedAction: .quarantineThreat
        )
        let result = TriageResult(
            decision: decision,
            confidenceScore: 0.94,
            decisiveness: 0.95,
            routingTier: .auto,
            latencyMs: 8.5,
            backendUsed: .onDeviceCoreML
        )
        var triagedEmail = sample
        triagedEmail.triageResult = result

        let triagedBar = DecisionActionBarView(store: store, email: triagedEmail)
        #expect(triagedBar.email.triageResult?.routingTier == .auto)
    }

    @Test("BatchSummarySheet initializes with report")
    func testBatchSummarySheet() {
        let report = BatchTriageReport(
            totalProcessed: 50,
            totalDurationSeconds: 1.2,
            averageLatencyMs: 8.4,
            actionBreakdown: [.scheduleTask: 30, .autoArchive: 20],
            backend: .onDeviceCoreML
        )
        let sheet = BatchSummarySheet(report: report)
        #expect(sheet.report.totalProcessed == 50)
        #expect(sheet.report.backend == .onDeviceCoreML)
    }

    @Test("BatchSummarySheet initializes with report and ground-truth")
    func testBatchSummarySheetWithGroundTruth() {
        let report = BatchTriageReport(
            totalProcessed: 50,
            totalDurationSeconds: 1.2,
            averageLatencyMs: 8.4,
            actionBreakdown: [.scheduleTask: 30, .autoArchive: 20],
            backend: .onDeviceCoreML
        )

        let hardware = BenchmarkHardwareInfo(deviceModel: "Apple Silicon Mac", chipName: "Apple Silicon Reference Hardware", osVersion: "macOS 15")
        let canonicalResult = BenchmarkBackendResult(
            backendName: "On-Device Core ML",
            endpointOrModel: "LayaDecisionModel.mlmodelc",
            sampleCount: 50,
            totalDurationSeconds: 0.44,
            throughputPerSecond: 113.6,
            meanLatencyMs: 8.8,
            p50LatencyMs: 8.5,
            p95LatencyMs: 12.1,
            totalTokens: 0,
            sampleDecisions: []
        )
        let groundTruth = BenchmarkTruthPayload(
            version: "1.0",
            generatedAt: Date(),
            hardwareInfo: hardware,
            sampleCount: 50,
            results: [.onDeviceCoreML: canonicalResult],
            isSyntheticReference: true
        )

        let sheet = BatchSummarySheet(report: report, groundTruth: groundTruth)
        #expect(sheet.report.totalProcessed == 50)
        #expect(sheet.report.backend == .onDeviceCoreML)
    }

    @Test("MailListView store reset updates state")
    func testMailListViewResetData() {
        let store = MailStore(emails: InboxData.sampleEmails)
        store.selectedMailbox = .archive
        store.unreadOnly = true
        store.searchText = "urgent"

        store.resetData()

        #expect(store.selectedMailbox == .inbox)
        #expect(!store.unreadOnly)
        #expect(store.searchText.isEmpty)
        #expect(store.filteredEmails.count == store.emails.filter { $0.mailbox == .inbox }.count)
    }

    @Test("SettingsView tab cases and initialization")
    func testSettingsViewTabs() {
        #expect(SettingsView.Tab.allCases.count == 4)
        #expect(SettingsView.Tab.backends.id == "Backends")
        #expect(SettingsView.Tab.backends.iconName == "server.rack")
        #expect(SettingsView.Tab.coreML.id == "On-Device Model")
        #expect(SettingsView.Tab.coreML.iconName == "cpu.fill")
        #expect(SettingsView.Tab.confidenceRouting.id == "Confidence Routing")
        #expect(SettingsView.Tab.confidenceRouting.iconName == "slider.horizontal.3")
        #expect(SettingsView.Tab.about.id == "About & Telemetry")
        #expect(SettingsView.Tab.about.iconName == "info.circle")

        let view = SettingsView()
        #expect(type(of: view) == SettingsView.self)
    }

    @Test("UrgencyPriority SwiftUI colors and labels map canonically (PRD-2)")
    func testUrgencyPrioritySwiftUIMapping() {
        #expect(UrgencyPriority.p0Critical.displayName == "P0 Critical")
        #expect(UrgencyPriority.p0Critical.color == .red)

        #expect(UrgencyPriority.p1High.displayName == "P1 High")
        #expect(UrgencyPriority.p1High.color == .orange)

        #expect(UrgencyPriority.p2Medium.displayName == "P2 Medium")
        #expect(UrgencyPriority.p2Medium.color == .blue)

        #expect(UrgencyPriority.p3Low.displayName == "P3 Low")
        #expect(UrgencyPriority.p3Low.color == .secondary)

        // Int extensions in SwiftUI
        #expect(0.urgencyPriority == .p0Critical)
        #expect(0.urgencyColor == .red)
        #expect(3.urgencyPriority == .p3Low)
        #expect(3.urgencyColor == .secondary)
    }

    @Test("ComposeMessageSheet initializes with pre-filled Reply / Forward parameters (PRD-3)")
    func testComposeMessageSheetInitialization() {
        let store = MailStore(emails: InboxData.sampleEmails)
        let sheet = ComposeMessageSheet(
            store: store,
            to: "sender@example.com",
            subject: "Re: Meeting notes",
            initialBody: "\n> Previous body"
        )
        #expect(sheet.toText == "sender@example.com")
        #expect(sheet.subjectText == "Re: Meeting notes")
        #expect(sheet.bodyText == "\n> Previous body")
        #expect(sheet.store === store)
    }
}
