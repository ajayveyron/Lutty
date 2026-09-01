import SwiftUI

struct EditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditorViewModel
    @State private var isLibraryPresented = false

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

                photoPreview

                if viewModel.isRendering && viewModel.previewImage == nil {
                    ProgressView()
                        .tint(AppTheme.editorForeground)
                        .controlSize(.large)
                }

                VStack {
                    Spacer()
                    GlassEffectContainer(spacing: AppTheme.controlSpacing) {
                        EditorControls(viewModel: viewModel, luts: lutStore.luts)
                    }
                    .padding(.horizontal, 12)
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
    private var photoPreview: some View {
        if let image = viewModel.isComparing ? viewModel.originalImage : viewModel.previewImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 214)
                .contentShape(Rectangle())
                .onLongPressGesture(
                    minimumDuration: .infinity,
                    maximumDistance: .infinity,
                    pressing: { isPressing in
                        viewModel.isComparing = isPressing
                    },
                    perform: {}
                )
                .accessibilityLabel("Edited photo")
                .accessibilityHint("Press and hold to compare with the original")
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
