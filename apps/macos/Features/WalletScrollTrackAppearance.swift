import SwiftUI

// 保留系统滚动条的显示偏好与拖动行为，只移除轨道底色。
struct WalletScrollTrackAppearance: NSViewRepresentable {
    func makeNSView(context: Context) -> ScrollTrackView { ScrollTrackView() }

    func updateNSView(_ nsView: ScrollTrackView, context: Context) {
        nsView.updateScrollView()
    }

    final class ScrollTrackView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateScrollView()
        }

        func updateScrollView() {
            guard let scrollView = enclosingScrollView else { return }
            scrollView.drawsBackground = false
            if let scroller = scrollView.verticalScroller, !(scroller is WalletTracklessScroller) {
                let replacement = WalletTracklessScroller(frame: scroller.frame)
                replacement.controlSize = scroller.controlSize
                replacement.scrollerStyle = scroller.scrollerStyle
                replacement.knobStyle = scroller.knobStyle
                scrollView.verticalScroller = replacement
            }
        }
    }
}

final class WalletTracklessScroller: NSScroller {
    override var isOpaque: Bool { false }
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}
}
