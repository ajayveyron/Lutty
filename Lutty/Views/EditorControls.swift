import SwiftUI

enum EditorControlSection: String, CaseIterable, Identifiable {
    case looks = "Looks"
    case adjustments = "Adjust"

    var id: Self { self }
}

struct EditorControls: View {
    @Bindable var viewModel: EditorViewModel
    let luts: [LUTDefinition]
    @Binding var section: EditorControlSection

    var body: some View {
        VStack(spacing: 14) {
            sectionPicker

            switch section {
            case .looks:
                lutStrip
                sliderControl
            case .adjustments:
                adjustmentReadout
            }
        }
        .padding(16)
        .foregroundStyle(AppTheme.editorForeground)
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous)
        )
        .onChange(of: section) { _, newSection in
            switch newSection {
            case .looks:
                viewModel.selectedAdjustment = .lut
            case .adjustments:
                if viewModel.selectedAdjustment == .lut {
                    viewModel.selectedAdjustment = .exposure
                }
            }
        }
        .onChange(of: viewModel.selectedAdjustment) { _, adjustment in
            section = adjustment == .lut ? .looks : .adjustments
        }
    }

    private var sectionPicker: some View {
        Picker("Editing controls", selection: $section) {
            ForEach(EditorControlSection.allCases) { section in
                Text(section.rawValue)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("Editor control section")
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

    private var adjustmentReadout: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.selectedAdjustment.systemImage)
                    .font(.body.weight(.medium))

                Text(viewModel.selectedAdjustment.title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text(formattedValue)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryEditorForeground)
            }

            Text("Swipe up or down to choose · left or right to adjust")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryEditorForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.selectedAdjustment.title)
        .accessibilityValue(formattedValue)
        .accessibilityHint("Swipe vertically on the photo to choose a setting, or horizontally to adjust its value")
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { viewModel.recipe[viewModel.selectedAdjustment] },
            set: { viewModel.recipe[viewModel.selectedAdjustment] = $0 }
        )
    }

    private var sliderRange: ClosedRange<Double> {
        viewModel.selectedAdjustment.valueRange
    }

    private var formattedValue: String {
        viewModel.selectedAdjustment.formattedValue(sliderBinding.wrappedValue)
    }
}
