import SwiftUI

struct LUTSelectionMenu: View {
    @Bindable var viewModel: EditorViewModel
    let luts: [LUTDefinition]
    let manageLibrary: () -> Void

    var body: some View {
        Menu {
            Button {
                viewModel.selectLUT(nil)
            } label: {
                menuLabel("Original", isSelected: viewModel.recipe.selectedLUTID == nil)
            }
            .menuActionDismissBehavior(.disabled)

            ForEach(luts) { lut in
                Button {
                    viewModel.selectLUT(lut.id)
                } label: {
                    menuLabel(lut.displayName, isSelected: viewModel.recipe.selectedLUTID == lut.id)
                }
                .menuActionDismissBehavior(.disabled)
            }

            Divider()

            Button("Manage LUTs", systemImage: "slider.horizontal.3", action: manageLibrary)
        }
        label: {
            Label("LUTs", systemImage: "camera.filters")
        }
    }

    @ViewBuilder
    private func menuLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
