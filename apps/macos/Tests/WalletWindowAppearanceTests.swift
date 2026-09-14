import XCTest
import SwiftUI
@testable import CreditCardMac

@MainActor
final class WalletWindowAppearanceTests: XCTestCase {
    func testWindowBackgroundIsUniformForEverySkinAppearanceAndTransparencySetting() throws {
        let suiteName = "wallet-background-tests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let appearance = WalletAppearance(defaults: defaults)

        for skin in WalletSkin.allCases {
            for scheme in [ColorScheme.light, .dark] {
                let palette = WalletPalette(skin: skin, scheme: scheme)
                let reference = ImageRenderer(content: palette.background.frame(width: 1, height: 1))
                let referenceBitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(reference.cgImage))
                let expected = try XCTUnwrap(referenceBitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB))
                for reduceTransparency in [false, true] {
                    appearance.reduceTransparency = reduceTransparency
                    let renderer = ImageRenderer(content: WalletBackground(palette: palette)
                        .frame(width: 800, height: 600)
                        .environmentObject(appearance)
                        .environment(\.colorScheme, scheme))
                    let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
                    for point in [(0, 0), (100, 100), (400, 300), (799, 599)] {
                        let actual = try XCTUnwrap(bitmap.colorAt(x: point.0, y: point.1)?.usingColorSpace(.sRGB))
                        XCTAssertEqual(actual.alphaComponent, 1)
                        XCTAssertEqual(actual.redComponent, expected.redComponent, accuracy: 0.01)
                        XCTAssertEqual(actual.greenComponent, expected.greenComponent, accuracy: 0.01)
                        XCTAssertEqual(actual.blueComponent, expected.blueComponent, accuracy: 0.01)
                    }
                }
            }
        }
    }

    func testScrollTrackConfigurationPreservesSystemStyleAndScrolling() throws {
        for style in [NSScroller.Style.legacy, .overlay] {
            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 300))
            scrollView.hasVerticalScroller = true
            scrollView.scrollerStyle = style
            let document = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 1000))
            scrollView.documentView = document
            let probe = WalletScrollTrackAppearance.ScrollTrackView()
            document.addSubview(probe)
            probe.updateScrollView()
            scrollView.tile()

            let scroller = try XCTUnwrap(scrollView.verticalScroller as? WalletTracklessScroller)
            XCTAssertFalse(scrollView.drawsBackground)
            XCTAssertFalse(scroller.isOpaque)
            XCTAssertEqual(scrollView.scrollerStyle, style)
            XCTAssertTrue(WalletTracklessScroller.isCompatibleWithOverlayScrollers)
            XCTAssertTrue(scroller.target === scrollView)
            XCTAssertNotNil(scroller.action)
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: 300))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            XCTAssertEqual(scrollView.contentView.bounds.origin.y, 300)
            XCTAssertGreaterThan(scroller.knobProportion, 0)
            XCTAssertLessThan(scroller.knobProportion, 1)
            probe.updateScrollView()
            XCTAssertTrue(scrollView.verticalScroller === scroller)
        }
    }

    func testSwiftUIScrollContentAttachesTrackAppearance() throws {
        let content = ScrollView {
            VStack {
                ForEach(0..<30) { Text("Row \($0)").frame(height: 30) }
            }
            .background(WalletScrollTrackAppearance())
        }.frame(width: 200, height: 300)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        defer { window.orderOut(nil) }
        let host = NSHostingView(rootView: content)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        func findScrollView(_ view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView { return scrollView }
            return view.subviews.lazy.compactMap(findScrollView).first
        }
        let scrollView = try XCTUnwrap(findScrollView(host))
        XCTAssertTrue(scrollView.verticalScroller is WalletTracklessScroller)
        XCTAssertFalse(scrollView.drawsBackground)
    }

    func testLegacyScrollerDoesNotPaintTrackBackground() throws {
        for name in [NSAppearance.Name.aqua, .darkAqua] {
            let scroller = WalletTracklessScroller(frame: NSRect(x: 0, y: 0, width: 15, height: 300))
            scroller.appearance = NSAppearance(named: name)
            scroller.scrollerStyle = .legacy
            scroller.knobProportion = 0.25
            scroller.doubleValue = 0
            let bitmap = try XCTUnwrap(scroller.bitmapImageRepForCachingDisplay(in: scroller.bounds))
            scroller.cacheDisplay(in: scroller.bounds, to: bitmap)
            // 顶部滑块之外的轨道应完全透明，包括两侧边缘。
            for x in [0, bitmap.pixelsWide / 2, bitmap.pixelsWide - 1] {
                let color = try XCTUnwrap(bitmap.colorAt(x: x, y: bitmap.pixelsHigh * 3 / 4))
                XCTAssertEqual(color.alphaComponent, 0)
            }
        }
    }
}
