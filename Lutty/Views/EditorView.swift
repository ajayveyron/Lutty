import SwiftUI

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PresetStore.self) private var presetStore
    @State private var viewModel: EditorViewModel
    @State private var isLibraryPresented = false
    @State private var isSavePresetPresented = false
    @State private var presetName = ""
    @State private var presetPendingDeletion: EditPreset?
    @State private var dragSession = AdjustmentDragSession()
    @State private var selectionHapticTrigger = 0
    @State private var valueHapticTrigger = 0
    @GestureState private var isComparing = false

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
                    horizontalValueIndicator
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

                    LUTSelectionMenu(
                        viewModel: viewModel,
                        luts: lutStore.luts,
                        manageLibrary: { isLibraryPresented = true }
                    )

                    PresetSelectionMenu(
                        viewModel: viewModel,
                        presets: presetStore.presets,
                        saveCurrentLook: presentSavePreset,
                        deletePreset: { presetPendingDeletion = $0 }
                    )

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

                ToolbarItem(placement: .principal) {
                    Text(adjustmentReadout)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(AppTheme.editorForeground)
                        .accessibilityLabel(viewModel.selectedAdjustment.title)
                        .accessibilityValue(
                            viewModel.selectedAdjustment.formattedValue(
                                viewModel.recipe[viewModel.selectedAdjustment]
                            )
                        )
                }
            }
            .task {
                viewModel.loadInitialPreview()
            }
            .onChange(of: viewModel.recipe) { _, _ in
                viewModel.schedulePreview()
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
                    ShareSheet(
                        items: [shareURL],
                        excludedActivityTypes: viewModel.excludedShareActivityTypes
                    )
                        .presentationDetents([.medium, .large])
                }
            }
            .alert("Lutty", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Try again.")
            }
            .alert("Save Preset", isPresented: $isSavePresetPresented) {
                TextField("Preset name", text: $presetName)
                Button("Cancel", role: .cancel) {}
                Button("Save", action: savePreset)
            } message: {
                Text("Save the LUT and every current adjustment.")
            }
            .confirmationDialog(
                "Delete \(presetPendingDeletion?.name ?? "preset")?",
                isPresented: deletePresetBinding,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive, action: deletePreset)
                Button("Cancel", role: .cancel) {
                    presetPendingDeletion = nil
                }
            }
        }
    }

    @ViewBuilder
    private var photoArea: some View {
        ZStack {
            if let image = isComparing ? viewModel.originalImage : viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Edited photo")
                    .accessibilityHint(
                        "Swipe vertically to choose an adjustment, horizontally to change its value, or press and hold to compare"
                    )
            }

            if viewModel.isRendering && viewModel.previewImage == nil {
                ProgressView()
                    .tint(AppTheme.editorForeground)
                    .controlSize(.large)
            }

            if dragSession.axis == .vertical {
                adjustmentSelectionOverlay
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(adjustmentGesture)
        .simultaneousGesture(compareGesture)
        .clipped()
    }

    private var adjustmentSelectionOverlay: some View {
        VStack(spacing: 0) {
            Image(systemName: "chevron.up")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryEditorForeground)
                .frame(height: 24)

            ForEach(AdjustmentKind.basicAdjustments) { adjustment in
                let isSelected = viewModel.selectedAdjustment == adjustment
                HStack(spacing: 16) {
                    Text(adjustment.title)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))

                    Spacer()

                    Text(adjustment.formattedValue(viewModel.recipe[adjustment]))
                        .font(.subheadline.monospacedDigit())
                }
                .foregroundStyle(AppTheme.editorForeground)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(isSelected ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .animation(.smooth(duration: 0.16), value: isSelected)
            }

            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryEditorForeground)
                .frame(height: 24)
        }
        .padding(6)
        .frame(width: 250)
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var horizontalValueIndicator: some View {
        let adjustment = viewModel.selectedAdjustment
        return HStack(spacing: 12) {
            Text(adjustment.title)
                .font(.caption.weight(.semibold))

            Slider(
                value: .constant(viewModel.recipe[adjustment]),
                in: adjustment.valueRange
            )
            .tint(AppTheme.editorForeground)
            .allowsHitTesting(false)

            Text(adjustment.formattedValue(viewModel.recipe[adjustment]))
                .font(.caption.monospacedDigit())
                .frame(minWidth: 38, alignment: .trailing)
        }
        .foregroundStyle(AppTheme.editorForeground)
        .padding(.horizontal, 16)
        .frame(height: 44)
        .accessibilityHidden(true)
    }

    private var adjustmentReadout: String {
        let adjustment = viewModel.selectedAdjustment
        return "\(adjustment.title) \(adjustment.formattedValue(viewModel.recipe[adjustment]))"
    }

    private var adjustmentGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                updateAdjustmentGesture(value)
            }
            .onEnded { _ in
                dragSession = AdjustmentDragSession()
            }
    }

    private var compareGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.2, maximumDistance: 18)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($isComparing) { value, state, _ in
                switch value {
                case .first(true), .second(true, _):
                    state = true
                default:
                    state = false
                }
            }
    }

    private func updateAdjustmentGesture(_ value: DragGesture.Value) {
        guard !isComparing else { return }

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
        case .saturation, .highlights, .shadows, .temperature, .dehaze: 0.1
        case .sharpness, .vignette, .filmGrain: 0.05
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func shareDismissed() {
        let notice = viewModel.exportNotice
        viewModel.shareDidDismiss()
        if let notice, notice != "Saved to Photos" {
            viewModel.errorMessage = notice
        }
    }

    private func presentSavePreset() {
        presetName = "Look \(presetStore.presets.count + 1)"
        isSavePresetPresented = true
    }

    private func savePreset() {
        do {
            try presetStore.save(name: presetName, recipe: viewModel.recipe)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private var deletePresetBinding: Binding<Bool> {
        Binding(
            get: { presetPendingDeletion != nil },
            set: { if !$0 { presetPendingDeletion = nil } }
        )
    }

    private func deletePreset() {
        guard let preset = presetPendingDeletion else { return }
        presetPendingDeletion = nil
        do {
            try presetStore.delete(preset)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

private struct AdjustmentDragSession {
    enum Axis: Equatable {
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
        let offset = Int(verticalTranslation / verticalSelectionDistance)
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
