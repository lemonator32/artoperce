#if canImport(UIKit)
import ArtoperceEngine
import SwiftUI

public struct GalleryView: View {
    @State private var items: [LibraryItem] = []
    @State private var path: [EditorModel] = []
    @State private var errorMessage: String?
    @State private var pendingDelete: LibraryItem?

    public init() {}

    public var body: some View {
        NavigationStack(path: $path) {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No artwork yet",
                        systemImage: "paintbrush.pointed",
                        description: Text("Choose New to start a canvas.")
                    )
                } else {
                    List {
                        ForEach(items) { item in
                            Button {
                                open(item.url)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.headline)
                                    Text(item.modified, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    pendingDelete = item
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Artoperce")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(Library.presets, id: \.name) { preset in
                            Button(preset.name) {
                                create(width: preset.width, height: preset.height)
                            }
                        }
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: EditorModel.self) { model in
                EditorView(model: model)
            }
        }
        .onAppear(perform: reload)
        .onChange(of: path) { _, newPath in
            if newPath.isEmpty { reload() }
        }
        .alert("Artoperce", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.name ?? "this artwork")?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Artwork", role: .destructive) {
                if let item = pendingDelete { delete(item) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes the artwork and its saved history.")
        }
    }

    private func reload() {
        items = Library.items()
    }

    private func open(_ url: URL) {
        do {
            path.append(try EditorModel.load(url: url))
        } catch {
            errorMessage = "This artwork could not be opened. \(error.localizedDescription)"
        }
    }

    private func create(width: Int, height: Int) {
        do {
            open(try Library.create(width: width, height: height))
        } catch {
            errorMessage = "The artwork could not be created. \(error.localizedDescription)"
        }
    }

    private func delete(_ item: LibraryItem) {
        do {
            try Library.delete(item.url)
            reload()
        } catch {
            errorMessage = "The artwork could not be deleted. \(error.localizedDescription)"
        }
    }
}
#endif
