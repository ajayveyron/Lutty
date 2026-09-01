import SwiftUI

struct EditorControls: View {
    @Bindable var viewModel: EditorViewModel
    let luts: [LUTDefinition]

    var body: some View {
        VStack(spacing: 16) {
            lutStrip
            sliderControl
            adjustmentBar
        }
        .padding(16)
        .foregroundStyle(AppTheme.editorForeground)
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous)
        )
    }

    private var lutStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                lutButton(name: "Original", systemImage: "photo", id: nil)
                ForEach(luts) { lut in
                    lutButton(name: lut.displayName, systemImage: "camera.filters", id: lut.id)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func lutButton(name: String, systemImage: String, id: UUID?) -> some View {
        let isSelected = viewModel.recipe.selectedLUTID == id
        return Button {
            viewModel.selectLUT(id)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(width: 74, height: 54)
            .background(isSelected ? AppTheme.selectedEditorControl : AppTheme.subduedEditorControl)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var sliderControl: some View {
        VStack(spacing: 8) {
            HStack {
                Text(viewModel.selectedAdjustment.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formattedValue)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryEditorForeground)
            }

            Slider(value: sliderBinding, in: sliderRange)
                .tint(AppTheme.editorForeground)
                .disabled(viewModel.selectedAdjustment == .lut && viewModel.recipe.selectedLUTID == nil)
        }
    }

    private var adjustmentBar: some View {
        HStack(spacing: 6) {
            ForEach(AdjustmentKind.allCases) { adjustment in
                let isSelected = viewModel.selectedAdjustment == adjustment
                Button {
                    viewModel.selectedAdjustment = adjustment
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: adjustment.systemImage)
                            .font(.body)
                        Text(adjustment.shortTitle)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(isSelected ? AppTheme.selectedEditorControl : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: {
                switch viewModel.selectedAdjustment {
                case .lut: viewModel.recipe.lutStrength
                case .exposure: viewModel.recipe.exposure
                case .contrast: viewModel.recipe.contrast
                case .saturation: viewModel.recipe.saturation
                case .temperature: viewModel.recipe.temperature
                }
            },
            set: { value in
                switch viewModel.selectedAdjustment {
                case .lut: viewModel.recipe.lutStrength = value
                case .exposure: viewModel.recipe.exposure = value
                case .contrast: viewModel.recipe.contrast = value
                case .saturation: viewModel.recipe.saturation = value
                case .temperature: viewModel.recipe.temperature = value
                }
            }
        )
    }

    private var sliderRange: ClosedRange<Double> {
        switch viewModel.selectedAdjustment {
        case .lut: 0...1
        case .exposure: -2...2
        case .contrast: 0.5...1.5
        case .saturation: 0...2
        case .temperature: -1...1
        }
    }

    private var formattedValue: String {
        let value = sliderBinding.wrappedValue
        return switch viewModel.selectedAdjustment {
        case .lut: value.formatted(.percent.precision(.fractionLength(0)))
        case .exposure: String(format: "%+.1f", value)
        case .contrast, .saturation: String(format: "%.2f", value)
        case .temperature: String(format: "%+.0f", value * 100)
        }
    }
}

private extension AdjustmentKind {
    var shortTitle: String {
        switch self {
        case .lut: "LUT"
        case .exposure: "Light"
        case .contrast: "Contrast"
        case .saturation: "Color"
        case .temperature: "Temp"
        }
    }
}
