import SwiftUI

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditorViewModel
    @State private var isLibraryPresented = false
    @State private var controlSection: EditorControlSection = .looks
    @State private var dragSession = AdjustmentDragSession()
    @State private var selectionHapticTrigger = 0
    @State private var valueHapticTrigger = 0

    private let lutStore: LUTStore

    init(asset: PhotoAsset, lutStore: LUTStore) {
        self.lutStore = lutStore
        _viewModel = State(initialValue: EditorViewModel(asset: asset, lutStore: lutStore))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ZStack {
                AppTheme.editorBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    photoArea

                    GlassEffectContainer(spacing: AppTheme.controlSpacing) {
                        EditorControls(
                            viewModel: viewModel,
                            luts: lutStore.luts,
                            section: $controlSection
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        viewModel.reset()
                    }

                    Button("LUTs", systemImage: "camera.filters") {
                        isLibraryPresented = true
                    }

                    Button {
                        viewModel.export()
                    } label: {
                        if viewModel.isExporting {
                            ProgressView()
                                .tint(AppTheme.editorForeground)
                        } else {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(viewModel.isExporting || viewModel.previewImage == nil)
                }
            }
            .task {
                viewModel.loadInitialPreview()
            }
            .onChange(of: viewModel.recipe) { _, _ in
                viewModel.schedulePreview()
            }
            .onChange(of: controlSection) { _, _ in
                dragSession = AdjustmentDragSession()
                viewModel.isComparing = false
            }
            .sensoryFeedback(.selection, trigger: selectionHapticTrigger)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.45), trigger: valueHapticTrigger)
            .sheet(isPresented: $isLibraryPresented) {
                NavigationStack {
                    LUTLibraryView()
                }
                .environment(lutStore)
            }
            .sheet(isPresented: $viewModel.isSharePresented, onDismiss: shareDismissed) {
                if let shareURL = viewModel.shareURL {
                    ShareSheet(items: [shareURL])
                        .presentationDetents([.medium, .large])
                }
            }
            .alert("Lutty", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Try again.")
            }
        }
    }

    @ViewBuilder
    private var photoArea: some View {
        ZStack {
            if let image = viewModel.isComparing ? viewModel.originalImage : viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onLongPressGesture(
                        minimumDuration: .infinity,
                        maximumDistance: .infinity,
                        pressing: { isPressing in
                            if controlSection == .looks {
                                viewModel.isComparing = isPressing
                            } else if !isPressing {
                                viewModel.isComparing = false
                            }
                        },
                        perform: {}
                    )
                    .accessibilityLabel("Edited photo")
                    .accessibilityHint(photoAccessibilityHint)
            }

            if viewModel.isRendering && viewModel.previewImage == nil {
                ProgressView()
                    .tint(AppTheme.editorForeground)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(adjustmentGesture)
        .clipped()
    }

    private var photoAccessibilityHint: String {
        switch controlSection {
        case .looks:
            "Press and hold to compare with the original"
        case .adjustments:
            "Swipe up or down to choose an adjustment, then left or right to change its value"
        }
    }

    private var adjustmentGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard controlSection == .adjustments else { return }
                updateAdjustmentGesture(value)
            }
            .onEnded { _ in
                dragSession = AdjustmentDragSession()
            }
    }

    private func updateAdjustmentGesture(_ value: DragGesture.Value) {
        if dragSession.axis == nil {
            let horizontalDistance = abs(value.translation.width)
            let verticalDistance = abs(value.translation.height)
            guard max(horizontalDistance, verticalDistance) >= 12 else { return }

            dragSession.axis = horizontalDistance > verticalDistance ? .horizontal : .vertical
            dragSession.startAdjustmentIndex = AdjustmentKind.basicAdjustments.firstIndex(
                of: viewModel.selectedAdjustment
            ) ?? 0
            dragSession.startValue = viewModel.recipe[viewModel.selectedAdjustment]
            dragSession.lastHapticStep = AdjustmentGestureMath.hapticStep(
                value: dragSession.startValue ?? 0,
                interval: hapticInterval(for: viewModel.selectedAdjustment)
            )
        }

        switch dragSession.axis {
        case .vertical:
            updateSelectedAdjustment(translation: value.translation.height)
        case .horizontal:
            updateAdjustmentValue(translation: value.translation.width)
        case nil:
            break
        }
    }

    private func updateSelectedAdjustment(translation: CGFloat) {
        let adjustments = AdjustmentKind.basicAdjustments
        let index = AdjustmentGestureMath.selectionIndex(
            start: dragSession.startAdjustmentIndex ?? 0,
            verticalTranslation: translation,
            count: adjustments.count
        )
        let adjustment = adjustments[index]
        guard adjustment != viewModel.selectedAdjustment else { return }

        viewModel.selectedAdjustment = adjustment
        selectionHapticTrigger += 1
    }

    private func updateAdjustmentValue(translation: CGFloat) {
        let adjustment = viewModel.selectedAdjustment
        guard adjustment != .lut, let startValue = dragSession.startValue else { return }

        let newValue = AdjustmentGestureMath.adjustedValue(
            start: startValue,
            horizontalTranslation: translation,
            range: adjustment.valueRange
        )
        guard newValue != viewModel.recipe[adjustment] else { return }

        viewModel.recipe[adjustment] = newValue
        let hapticStep = AdjustmentGestureMath.hapticStep(
            value: newValue,
            interval: hapticInterval(for: adjustment)
        )
        if hapticStep != dragSession.lastHapticStep {
            dragSession.lastHapticStep = hapticStep
            valueHapticTrigger += 1
        }
    }

    private func hapticInterval(for adjustment: AdjustmentKind) -> Double {
        switch adjustment {
        case .lut: 0.05
        case .exposure: 0.2
        case .contrast: 0.05
        case .saturation, .temperature: 0.1
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func shareDismissed() {
        if let notice = viewModel.exportNotice, notice != "Saved to Photos" {
            viewModel.errorMessage = notice
        }
    }
}

private struct AdjustmentDragSession {
    enum Axis {
        case horizontal
        case vertical
    }

    var axis: Axis?
    var startAdjustmentIndex: Int?
    var startValue: Double?
    var lastHapticStep: Int?
}

struct AdjustmentGestureMath {
    static let verticalSelectionDistance: CGFloat = 48
    static let horizontalFullRangeDistance: CGFloat = 640

    static func selectionIndex(start: Int, verticalTranslation: CGFloat, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let offset = Int(-verticalTranslation / verticalSelectionDistance)
        return min(max(start + offset, 0), count - 1)
    }

    static func adjustedValue(
        start: Double,
        horizontalTranslation: CGFloat,
        range: ClosedRange<Double>
    ) -> Double {
        let span = range.upperBound - range.lowerBound
        let change = span * Double(horizontalTranslation / horizontalFullRangeDistance)
        return min(max(start + change, range.lowerBound), range.upperBound)
    }

    static func hapticStep(value: Double, interval: Double) -> Int {
        Int((value / interval).rounded())
    }
}
