import SwiftUI
import AppCore

/// Floating bottom drawer anchored to the message detail view using Liquid Glass ergonomics.
/// Displays calibrated confidence metrics, operational routing tiers, and 1-click action triggers.
public struct DecisionActionBarView: View {
    @Bindable public var store: MailStore
    public let email: Email

    public init(store: MailStore, email: Email) {
        self.store = store
        self.email = email
    }

    public var body: some View {
        Group {
            if let result = email.triageResult {
                triagedBar(result: result)
            } else {
                untriagedBar
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Triaged State

    @ViewBuilder
    private func triagedBar(result: TriageResult) -> some View {
        VStack(spacing: 10) {
            // Top Row: Category, Urgency, Certainty, Tier Badge
            HStack(alignment: .center, spacing: 8) {
                // Category Pill
                Label(result.decision.category.displayName, systemImage: result.decision.category.iconName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())

                // Urgency Score Pill
                urgencyPill(score: result.decision.urgencyScore)

                // Calibrated Confidence Pill
                confidencePill(result: result)

                // Routing Tier Status Badge
                tierStatusBadge(tier: result.routingTier)

                Spacer(minLength: 4)

                // Backend Latency Telemetry
                HStack(spacing: 4) {
                    Image(systemName: result.backendUsed.iconName)
                        .font(.caption2)
                    Text(result.formattedLatency)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }

            // Bottom Row: Action Guidance & Execution Buttons
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: result.decision.suggestedAction.iconName)
                        .font(.caption)
                        .foregroundStyle(actionColor(for: result.decision.suggestedAction))
                    Text("Action: \(result.decision.suggestedAction.displayName)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }

                Spacer()

                // Operational Action Triggers
                switch result.routingTier {
                case .auto:
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Auto-Applied")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.12), in: Capsule())

                case .confirm:
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            store.executeSuggestedAction(for: email.id)
                        }
                    } label: {
                        Label(result.decision.suggestedAction.displayName, systemImage: result.decision.suggestedAction.iconName)
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                case .escalate:
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Review Required")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.12), in: Capsule())
                }

                // Re-evaluate button
                Button {
                    Task {
                        await store.triageEmail(id: email.id)
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Re-evaluate with selected backend")
            }
        }
    }

    // MARK: - Untriaged State

    @ViewBuilder
    private var untriagedBar: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.accentColor)
                    Text("System One Decision Model")
                        .font(.subheadline.weight(.semibold))
                }
                Text("Evaluate with \(store.selectedBackend.displayName) (\(store.selectedBackend.latencyDescription))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.isTriagingSingleEmail {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Triaging...")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Task {
                        await store.triageEmail(id: email.id)
                    }
                } label: {
                    Label("Triage with Model", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Helper Badges

    @ViewBuilder
    private func urgencyPill(score: Int) -> some View {
        let priority = UrgencyPriority.from(score: score)
        Text(priority.displayName)
            .font(.caption2.weight(.bold))
            .foregroundStyle(priority.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(priority.color.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(priority.color.opacity(0.24), lineWidth: 0.5)
            )
    }

    @ViewBuilder
    private func confidencePill(result: TriageResult) -> some View {
        let color: Color = {
            switch result.routingTier {
            case .auto: return .green
            case .confirm: return .yellow
            case .escalate: return .orange
            }
        }()

        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(result.confidencePercentage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private func tierStatusBadge(tier: RoutingPolicy) -> some View {
        let color: Color = {
            switch tier {
            case .auto: return .green
            case .confirm: return .blue
            case .escalate: return .orange
            }
        }()

        Text(tier.statusBadgeText)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    private func actionColor(for action: TriageAction) -> Color {
        switch action {
        case .immediateAlert, .quarantineThreat:
            return .red
        case .scheduleTask:
            return .blue
        case .draftReply:
            return .purple
        case .autoArchive:
            return .gray
        case .moveToInbox:
            return .green
        }
    }
}

#Preview {
    let store = MailStore()
    let sample = InboxData.sampleEmails[0]
    DecisionActionBarView(store: store, email: sample)
        .padding()
}
