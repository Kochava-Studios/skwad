import SwiftUI
import AppKit

/// NSView that detects 3-finger double-tap on the trackpad
final class ThreeFingerDoubleTapView: NSView {

    var onDoubleTap: (() -> Void)?

    private var lastThreeFingerTapTime: Date?
    private let doubleTapInterval: TimeInterval = 0.4

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        guard touches.count == 3 else { return }

        let now = Date()
        if let last = lastThreeFingerTapTime, now.timeIntervalSince(last) < doubleTapInterval {
            lastThreeFingerTapTime = nil
            onDoubleTap?()
        } else {
            lastThreeFingerTapTime = now
        }
    }
}

/// NSViewRepresentable wrapper
struct ThreeFingerDoubleTapOverlay: NSViewRepresentable {
    let onDoubleTap: () -> Void

    func makeNSView(context: Context) -> ThreeFingerDoubleTapView {
        let view = ThreeFingerDoubleTapView()
        view.onDoubleTap = onDoubleTap
        return view
    }

    func updateNSView(_ nsView: ThreeFingerDoubleTapView, context: Context) {
        nsView.onDoubleTap = onDoubleTap
    }
}

extension View {
    /// Overlay an invisible 3-finger double-tap detector on this view
    func onThreeFingerDoubleTap(perform action: @escaping () -> Void) -> some View {
        background(ThreeFingerDoubleTapOverlay(onDoubleTap: action))
    }
}
