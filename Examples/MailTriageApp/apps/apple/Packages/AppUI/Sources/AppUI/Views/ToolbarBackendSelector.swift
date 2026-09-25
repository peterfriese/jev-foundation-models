import SwiftUI
import AppCore

/// A compact, polished capsule picker embedded in the unified navigation toolbar
/// allowing instant switching between the five System One decision model backend architectures.
public struct ToolbarBackendSelector: View {
    @Bindable public var store: MailStore

    public init(store: MailStore) {
        self.store = store
    }

    public var body: some View {
        Menu {
            Section("Decision Model Topologies") {
                ForEach(TriageBackend.allCases.filter(\.isDecisionModel)) { backend in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            store.selectedBackend = backend
                        }
                    } label: {
                        HStack {
                            Label(backend.displayName, systemImage: backend.iconName)
                            Spacer()
                            Text(backend.latencyDescription)
                                .foregroundStyle(.secondary)
                            if store.selectedBackend == backend {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section("Baseline Comparison") {
                ForEach(TriageBackend.allCases.filter { !$0.isDecisionModel }) { backend in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            store.selectedBackend = backend
                        }
                    } label: {
                        HStack {
                            Label(backend.displayName, systemImage: backend.iconName)
                            Spacer()
                            Text(backend.latencyDescription)
                                .foregroundStyle(.secondary)
                            if store.selectedBackend == backend {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: store.selectedBackend.iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(store.selectedBackend.isDecisionModel ? Color.accentColor : Color.purple)

                Text(store.selectedBackend.shortName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)

                Text(store.selectedBackend.latencyDescription)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    #if os(macOS)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                    #endif

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Select System One Inference Backend Architecture")
        .accessibilityLabel("Active Backend: \(store.selectedBackend.displayName)")
    }
}

#Preview {
    let store = MailStore()
    ToolbarBackendSelector(store: store)
        .padding()
}
