import SwiftUI

struct LUTLibraryView: View {
    @Environment(LUTStore.self) private var lutStore

    @State private var isImporterPresented = false
    @State private var renameTarget: LUTDefinition?
    @State private var renameValue = ""
    @State private var deleteTarget: LUTDefinition?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if lutStore.luts.isEmpty {
                ContentUnavailableView {
                    Label("No LUTs yet", systemImage: "camera.filters")
                } description: {
                    Text("Import a .cube file from Files.")
                } actions: {
                    Button("Import LUT", systemImage: "square.and.arrow.down") {
                        isImporterPresented = true
                    }
                    .buttonStyle(.glassProminent)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(lutStore.luts) { lut in
                            lutRow(lut)
                        }
                    }
                    .padding(AppTheme.pagePadding)
                }
                .background(AppTheme.groupedBackground)
            }
        }
        .navigationTitle("LUT Library")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Import", systemImage: "plus") {
                    isImporterPresented = true
                }
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.cubeLUT],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                try lutStore.importLUT(from: url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .alert("Rename LUT", isPresented: renameBinding) {
            TextField("Name", text: $renameValue)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Save") {
                guard let renameTarget else { return }
                do {
                    try lutStore.rename(renameTarget, to: renameValue)
                } catch {
                    errorMessage = error.localizedDescription
                }
                self.renameTarget = nil
            }
        }
        .alert("Delete LUT?", isPresented: deleteBinding) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) {
                guard let deleteTarget else { return }
                do {
                    try lutStore.delete(deleteTarget)
                } catch {
                    errorMessage = error.localizedDescription
                }
                self.deleteTarget = nil
            }
        } message: {
            Text("You can import this file again later.")
        }
        .alert("Couldn’t update library", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try again.")
        }
    }

    private func lutRow(_ lut: LUTDefinition) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 46, height: 46)
                .background(AppTheme.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(lut.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(lut.cubeSize)³ color cube")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button("Rename", systemImage: "pencil") {
                    renameValue = lut.displayName
                    renameTarget = lut
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    deleteTarget = lut
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(16)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
