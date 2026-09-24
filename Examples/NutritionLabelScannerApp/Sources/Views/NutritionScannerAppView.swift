import SwiftUI

// MARK: - Root Coordinator View (Camera Viewfinder + Interactive Sheet)

public struct NutritionScannerAppView: View {
    @State private var viewModel = ScannerViewModel()
    @State private var isSheetPresented: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // (a) Full-Bleed Camera Viewfinder + (c) Diet Selector Dropdown
            CameraViewfinderView(
                viewModel: viewModel,
                isSheetPresented: $isSheetPresented
            )
        }
        .sheet(isPresented: $isSheetPresented) {
            // (d) Safety Indicators + (b) Nutrition Values
            NutritionSheetView(
                viewModel: viewModel,
                isSheetPresented: $isSheetPresented
            )
            .presentationDetents([.fraction(0.55), .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            viewModel.onScanCompleted = {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isSheetPresented = true
                }
            }
        }
    }
}
