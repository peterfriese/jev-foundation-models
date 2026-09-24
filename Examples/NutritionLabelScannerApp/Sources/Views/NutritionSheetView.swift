import SwiftUI

// MARK: - Interactive Nutrition & Safety Sheet (Apple HIG Canonical Sheet)

public struct NutritionSheetView: View {
    @Bindable var viewModel: ScannerViewModel
    @Binding var isSheetPresented: Bool
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: ScannerViewModel, isSheetPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isSheetPresented = isSheetPresented
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Product Title & Action Header
                productHeader

                // (d) Safety Indicator Banner
                SafetyIndicatorBanner(
                    decision: viewModel.decision,
                    isSafeProbability: viewModel.isSafeProbability,
                    latencyMs: viewModel.latencyMs,
                    profile: viewModel.selectedProfile,
                    isEvaluating: viewModel.isEvaluating
                )

                // (b) Nutrition Values Display
                VStack(alignment: .leading, spacing: 10) {
                    Text("Nutrition Facts")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    NutritionTableView(nutrition: viewModel.selectedProduct.nutrition)
                }

                // Ingredients Statement
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ingredients")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(viewModel.selectedProduct.ingredientsText)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineSpacing(3)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let warning = viewModel.selectedProduct.facilityWarning, !warning.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                                .padding(.top, 2)
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                }

                // Jev Decision Telemetry
                if viewModel.decision != nil {
                    decisionTelemetryFooter
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Product Header

    private var productHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(viewModel.selectedProduct.brand.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(viewModel.selectedProduct.packageCategory)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(viewModel.selectedProduct.name)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            // Status Indicator & Dismiss Button
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.badge.questionmark.fill")
                        .font(.caption)
                    Text(viewModel.selectedProfile.shortName)
                        .font(.caption.bold())
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(Capsule())

                // Explicit Dismiss Button
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    isSheetPresented = false
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
    }

    // MARK: - Telemetry Footer

    private var decisionTelemetryFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Decision Model Telemetry")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack {
                Text("TypeSafe Jev System One")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f ms", viewModel.latencyMs))
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                Text("•")
                    .foregroundStyle(.secondary)
                Text("\(viewModel.tokenUsage.input) in / \(viewModel.tokenUsage.output) out")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.top, 4)
    }
}
