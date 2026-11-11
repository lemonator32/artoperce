#if canImport(UIKit)
import ArtoperceEngine
import SwiftUI
import UIKit

struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

struct EditorView: View {
    @ObservedObject var model: EditorModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLayers = false
    @State private var shareItem: ShareItem?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            CanvasRepresentable(model: model)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showLayers) {
            LayerListView(model: model)
        }
        .sheet(item: $shareItem) { item in
            ActivityView(url: item.url)
        }
        .alert("Artoperce", isPresented: Binding(
            get: { model.notice != nil || errorMessage != nil },
            set: { if !$0 { model.notice = nil; errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? model.notice ?? "")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Label("Gallery", systemImage: "chevron.backward")
            }
            Text(model.url.deletingPathExtension().lastPathComponent)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Button { model.undo() } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo)
            Button { model.redo() } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!model.canRedo)
            Button { showLayers = true } label: {
                Label("Layers", systemImage: "square.3.layers.3d")
            }
            Button { export() } label: {
                Label("Export PNG", systemImage: "square.and.arrow.up")
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var bottomBar: some View {
        HStack(spacing: 18) {
            Toggle(isOn: $model.isEraser) {
                Label("Eraser", systemImage: "eraser")
            }
            .toggleStyle(.button)

            ColorPicker("Color", selection: $model.color, supportsOpacity: false)
                .labelsHidden()

            HStack(spacing: 8) {
                Text("Size").font(.caption).foregroundStyle(.secondary)
                Slider(value: $model.diameter, in: 1...200)
                    .frame(width: 180)
                Text("\(Int(model.diameter)) px")
                    .font(.caption.monospacedDigit())
                    .frame(width: 56, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("Opacity").font(.caption).foregroundStyle(.secondary)
                Slider(value: $model.opacity, in: 0.05...1)
                    .frame(width: 140)
                Text("\(Int(model.opacity * 100))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 44, alignment: .leading)
            }

            Toggle(isOn: $model.fingerDrawingEnabled) {
                Label("Draw with finger", systemImage: "hand.draw")
            }
            .toggleStyle(.button)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func export() {
        do {
            shareItem = ShareItem(url: try model.exportPNG())
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

struct LayerListView: View {
    @ObservedObject var model: EditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Top layer first, matching how the stack looks on screen.
                ForEach(model.layers.reversed()) { layer in
                    LayerRow(layer: layer, model: model)
                }
            }
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.addLayer() } label: {
                        Label("Add Layer", systemImage: "plus")
                    }
                }
            }
        }
    }
}

struct LayerRow: View {
    let layer: Layer
    @ObservedObject var model: EditorModel

    private var isActive: Bool { model.activeLayerID == layer.id }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.selectLayer(layer)
            } label: {
                Label(layer.name, systemImage: isActive ? "checkmark.circle.fill" : "circle")
                    .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                model.setVisible(!layer.isVisible, for: layer)
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(layer.isVisible ? "Hide \(layer.name)" : "Show \(layer.name)")
            Slider(
                value: Binding(
                    get: { layer.opacity },
                    set: { model.setOpacity($0, for: layer) }
                ),
                in: 0...1
            )
            .frame(width: 140)
            .accessibilityLabel("\(layer.name) opacity")
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
