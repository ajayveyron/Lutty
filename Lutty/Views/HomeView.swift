import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

private enum PhotoImportError: LocalizedError {
    case unsupportedFormat
    case unreadablePhoto

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            "Choose a JPEG, HEIC, or PNG still photo. RAW and Live Photos are not supported yet."
        case .unreadablePhoto:
            "This photo could not be loaded."
        }
    }
}

struct HomeView: View {
    @Environment(LUTStore.self) private var lutStore

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var editorAsset: PhotoAsset?
    @State private var isPhotoPickerPresented = false
    @State private var hasPresentedInitialPhotoPicker = false
    @State private var isLoadingPhoto = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    introduction
                    photoCard
                    libraryCard
                }
                .padding(AppTheme.pagePadding)
            }
            .background(AppTheme.groupedBackground)
            .navigationTitle("Lutty")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(item: $editorAsset) { asset in
                EditorView(asset: asset, lutStore: lutStore)
            }
            .alert("Couldn’t open photo", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Try another photo.")
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                loadPhoto(item)
            }
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .task {
            guard !hasPresentedInitialPhotoPicker else { return }
            hasPresentedInitialPhotoPicker = true
            guard !ProcessInfo.processInfo.arguments.contains("-SkipInitialPhotoPicker") else { return }
            await Task.yield()
            isPhotoPickerPresented = true
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your looks. Your photos.")
                .font(.title2.weight(.semibold))
            Text("Import a LUT, tune the color, save a new copy.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var photoCard: some View {
        let loading = isLoadingPhoto
        return VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 54, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Start with a photo")
                    .font(.title3.weight(.semibold))
                Text("JPEG, HEIC, or PNG")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                isPhotoPickerPresented = true
            } label: {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Choose Photo", systemImage: "photo.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(loading)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
    }

    private var libraryCard: some View {
        NavigationLink {
            LUTLibraryView()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "camera.filters")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("LUT Library")
                        .font(.headline)
                    Text(libraryDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.primary)
            .padding(18)
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var libraryDescription: String {
        switch lutStore.luts.count {
        case 0: "Import your first .cube file"
        case 1: "1 look saved on this iPhone"
        default: "\(lutStore.luts.count) looks saved on this iPhone"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func loadPhoto(_ item: PhotosPickerItem) {
        isLoadingPhoto = true
        Task {
            defer {
                isLoadingPhoto = false
                selectedPhotoItem = nil
            }
            do {
                let contentTypes = item.supportedContentTypes
                if contentTypes.contains(where: { $0.conforms(to: .livePhoto) || $0.conforms(to: .rawImage) }) {
                    throw PhotoImportError.unsupportedFormat
                }

                let isPNG = contentTypes.contains(where: { $0.conforms(to: .png) })
                let isSupported = isPNG || contentTypes.contains(where: {
                    $0.conforms(to: .jpeg) || $0.conforms(to: .heic) || $0.conforms(to: .heif)
                })
                guard isSupported else { throw PhotoImportError.unsupportedFormat }
                guard let data = try await item.loadTransferable(type: Data.self),
                      UIImage(data: data) != nil else {
                    throw PhotoImportError.unreadablePhoto
                }
                editorAsset = PhotoAsset(data: data, isPNG: isPNG)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(LUTStore(rootURL: FileManager.default.temporaryDirectory.appending(path: "LuttyPreview")))
        .environment(PresetStore(rootURL: FileManager.default.temporaryDirectory.appending(path: "LuttyPreview")))
}
