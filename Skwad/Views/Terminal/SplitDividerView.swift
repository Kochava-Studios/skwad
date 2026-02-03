import SwiftUI
import AppKit

/// NSViewRepresentable divider that sits above terminal NSViews and handles drag to resize
struct SplitDividerView: NSViewRepresentable {
  let isVertical: Bool
  let onDrag: (CGFloat) -> Void
  let onDragEnd: () -> Void

  func makeNSView(context: Context) -> SplitDividerNSView {
    let view = SplitDividerNSView()
    view.isVertical = isVertical
    view.onDrag = onDrag
    view.onDragEnd = onDragEnd
    return view
  }

  func updateNSView(_ nsView: SplitDividerNSView, context: Context) {
    nsView.isVertical = isVertical
    nsView.onDrag = onDrag
    nsView.onDragEnd = onDragEnd
    nsView.needsDisplay = true
  }
}

class SplitDividerNSView: NSView {
  var isVertical: Bool = true
  var onDrag: ((CGFloat) -> Void)?
  var onDragEnd: (() -> Void)?
  private var dragStartLocation: NSPoint?
  private var trackingArea: NSTrackingArea?

  override init(frame: NSRect) {
    super.init(frame: frame)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let existing = trackingArea {
      removeTrackingArea(existing)
    }
    trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.mouseEnteredAndExited, .activeInKeyWindow, .cursorUpdate],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea!)
  }

  override func cursorUpdate(with event: NSEvent) {
    if isVertical {
      NSCursor.resizeLeftRight.set()
    } else {
      NSCursor.resizeUpDown.set()
    }
  }

  override func mouseEntered(with event: NSEvent) {
    if isVertical {
      NSCursor.resizeLeftRight.push()
    } else {
      NSCursor.resizeUpDown.push()
    }
  }

  override func mouseExited(with event: NSEvent) {
    NSCursor.pop()
  }

  override func mouseDown(with event: NSEvent) {
    dragStartLocation = event.locationInWindow
  }

  override func mouseDragged(with event: NSEvent) {
    guard let start = dragStartLocation else { return }
    let current = event.locationInWindow
    let delta = isVertical ? current.x - start.x : -(current.y - start.y)
    onDrag?(delta)
  }

  override func mouseUp(with event: NSEvent) {
    dragStartLocation = nil
    onDragEnd?()
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    // Draw subtle center line
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.setFillColor(NSColor.separatorColor.withAlphaComponent(0.3).cgColor)

    if isVertical {
      let lineRect = CGRect(x: bounds.midX - 0.5, y: 0, width: 1, height: bounds.height)
      context.fill(lineRect)
    } else {
      let lineRect = CGRect(x: 0, y: bounds.midY - 0.5, width: bounds.width, height: 1)
      context.fill(lineRect)
    }
  }
}
