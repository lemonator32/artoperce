#if canImport(UIKit)
import ArtoperceEngine
import SwiftUI
import UIKit

/// Hosts the document and handles all canvas input.
///
/// Drawing: a pencil always draws. A finger draws when "Draw with finger" is on.
/// Navigation: two-finger pan and pinch zoom. With finger drawing off, one finger pans.
/// Display: one CALayer per tile, so a stroke redraws only the tiles it touched.
final class CanvasView: UIView, UIGestureRecognizerDelegate {
    weak var model: EditorModel?

    /// Document space. One unit is one document pixel.
    private let content = UIView()
    private let paper = CALayer()
    private var tileLayers: [TileKey: CALayer] = [:]

    private var zoom: CGFloat = 1
    private var offset: CGPoint = .zero
    private var hasFitted = false
    private var activeTouch: UITouch?

    private lazy var pan: UIPanGestureRecognizer = {
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        return recognizer
    }()

    private lazy var pinch: UIPinchGestureRecognizer = {
        let recognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        return recognizer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.12, alpha: 1)
        isMultipleTouchEnabled = true
        content.layer.masksToBounds = true
        paper.backgroundColor = UIColor.white.cgColor
        content.layer.addSublayer(paper)
        addSubview(content)
        addGestureRecognizer(pan)
        addGestureRecognizer(pinch)
    }

    required init?(coder: NSCoder) { fatalError("CanvasView is created in code") }

    /// Attaches a document. Called once, when the representable is created.
    func attach(_ model: EditorModel) {
        self.model = model
        content.bounds = CGRect(x: 0, y: 0, width: model.document.width, height: model.document.height)
        paper.frame = content.bounds
        model.onTilesChanged = { [weak self] keys in self?.refresh(keys) }
        refresh(model.document.occupiedTileKeys)
        setNeedsLayout()
    }

    // MARK: - Layout and viewport

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let model, bounds.width > 0 else { return }
        if !hasFitted {
            hasFitted = true
            fitToScreen(documentSize: CGSize(width: model.document.width, height: model.document.height))
        }
        applyViewport()
    }

    private func fitToScreen(documentSize: CGSize) {
        let margin: CGFloat = 40
        let scale = min(
            (bounds.width - margin * 2) / documentSize.width,
            (bounds.height - margin * 2) / documentSize.height
        )
        zoom = max(0.05, min(scale, 1))
        offset = CGPoint(
            x: (bounds.width - documentSize.width * zoom) / 2,
            y: (bounds.height - documentSize.height * zoom) / 2
        )
    }

    /// Positions the document view with a top-left anchored zoom.
    /// Transform is scale around the view centre, so the centre is set explicitly.
    private func applyViewport() {
        guard let model else { return }
        let size = CGSize(width: CGFloat(model.document.width), height: CGFloat(model.document.height))
        content.transform = .identity
        content.bounds = CGRect(origin: .zero, size: size)
        content.center = CGPoint(
            x: offset.x + size.width * zoom / 2,
            y: offset.y + size.height * zoom / 2
        )
        content.transform = CGAffineTransform(scaleX: zoom, y: zoom)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self)
        offset.x += translation.x
        offset.y += translation.y
        recognizer.setTranslation(.zero, in: self)
        applyViewport()
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        let newZoom = max(0.05, min(zoom * recognizer.scale, 32))
        recognizer.scale = 1
        // Keep the document point under the pinch centre fixed on screen.
        let anchor = recognizer.location(in: self)
        let documentPoint = CGPoint(x: (anchor.x - offset.x) / zoom, y: (anchor.y - offset.y) / zoom)
        zoom = newZoom
        offset = CGPoint(x: anchor.x - documentPoint.x * zoom, y: anchor.y - documentPoint.y * zoom)
        applyViewport()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    /// With finger drawing on, navigation needs two fingers. Otherwise one finger navigates.
    func updateNavigationTouchCount() {
        let fingerDraws = model?.fingerDrawingEnabled ?? true
        pan.minimumNumberOfTouches = fingerDraws ? 2 : 1
    }

    // MARK: - Drawing input

    private func canDraw(_ touch: UITouch) -> Bool {
        switch touch.type {
        case .pencil: return true
        case .direct: return model?.fingerDrawingEnabled ?? true
        default: return false
        }
    }

    private func sample(for touch: UITouch) -> StrokeSample {
        let point = touch.location(in: content)
        let pressure: Double
        if touch.type == .pencil, touch.maximumPossibleForce > 0 {
            pressure = max(0.05, Double(touch.force / touch.maximumPossibleForce))
        } else {
            pressure = 1
        }
        return StrokeSample(x: Double(point.x), y: Double(point.y), pressure: pressure)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let count = event?.allTouches?.count ?? 1
        if let active = activeTouch {
            // A pencil stroke ignores other touches, which are usually a resting palm.
            // A finger stroke is cancelled by a second finger, which is a navigation gesture.
            // A cancelled stroke is undone, not committed.
            if active.type != .pencil, count > 1 {
                model?.cancelStroke()
                activeTouch = nil
            }
            return
        }
        guard count == 1, let touch = touches.first, canDraw(touch), let model else { return }
        activeTouch = touch
        model.beginStroke()
        model.continueStroke([sample(for: touch)])
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch), let model else { return }
        let coalesced = event?.coalescedTouches(for: touch) ?? [touch]
        model.continueStroke(coalesced.map(sample(for:)))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch), let model else { return }
        model.continueStroke([sample(for: touch)])
        model.endStroke()
        activeTouch = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        model?.cancelStroke()
        activeTouch = nil
    }

    // MARK: - Tile display

    /// Redraws the given tiles from the document, with any stroke in progress.
    func refresh(_ keys: Set<TileKey>) {
        guard let model else { return }
        for key in keys {
            let layer = tileLayers[key] ?? makeTileLayer(for: key)
            layer.contents = model.image(for: key)
        }
    }

    private func makeTileLayer(for key: TileKey) -> CALayer {
        let layer = CALayer()
        layer.frame = CGRect(x: key.x * tileSize, y: key.y * tileSize, width: tileSize, height: tileSize)
        layer.magnificationFilter = .nearest
        layer.minificationFilter = .trilinear
        content.layer.addSublayer(layer)
        tileLayers[key] = layer
        return layer
    }
}

/// SwiftUI bridge for the canvas.
struct CanvasRepresentable: UIViewRepresentable {
    let model: EditorModel

    func makeUIView(context: Context) -> CanvasView {
        let view = CanvasView()
        view.attach(model)
        return view
    }

    func updateUIView(_ view: CanvasView, context: Context) {
        view.updateNavigationTouchCount()
    }
}
#endif
