import SwiftUI

private struct AttachmentPreviewRequest: Identifiable {
    let id = UUID()
    let index: Int
    let images: [CardImageAsset]
}

struct CardAttachmentStrip: View {
    let images: [CardImageAsset]
    var nested = false
    @State private var preview: AttachmentPreviewRequest?
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletSheetSize) private var sheetSize

    var body: some View {
        if !images.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("附件照片", systemImage: "photo.on.rectangle").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button("查看 \(images.count) 张") { preview = AttachmentPreviewRequest(index: 0, images: images) }
                        .buttonStyle(.borderless).font(.caption)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(images.indices, id: \.self) { index in
                            Button { preview = AttachmentPreviewRequest(index: index, images: images) } label: {
                                CardImageView(asset: images[index], pixels: 240)
                                    .frame(width: 102, height: 70)
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(palette.line, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .help("打开照片预览")
                            .accessibilityLabel(Text("查看第 \(index + 1) 张照片"))
                        }
                    }.padding(2)
                }
            }
            .sheet(item: $preview) { request in
                CardAttachmentViewer(images: request.images, initialIndex: request.index)
                    .id(request.id)
                    .environment(\.walletSheetSize, nested ? WalletSheetLayout.size(in: sheetSize) : sheetSize)
            }
            .onChange(of: images.map(\.id)) { _, _ in preview = nil }
        }
    }
}

struct CardAttachmentViewer: View {
    let images: [CardImageAsset]
    @State private var selectedIndex: Int
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @Environment(\.dismiss) private var dismiss
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletSheetSize) private var sheetSize
    @Environment(\.walletIsLocked) private var isLocked

    init(images: [CardImageAsset], initialIndex: Int = 0) {
        self.images = images
        _selectedIndex = State(initialValue: min(max(0, initialIndex), max(0, images.count - 1)))
    }

    var body: some View {
        Group {
            if isLocked {
                LockScreenView()
            } else {
                VStack(spacing: 0) {
                    WalletSheetHeader(title: "附件照片", subtitle: images.isEmpty ? String(localized: "暂无附件照片") : images[selectedIndex].name, icon: "photo.on.rectangle") {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).help("关闭").accessibilityLabel("关闭").keyboardShortcut(.cancelAction)
                    }
                    if images.isEmpty {
                        ContentUnavailableView("暂无附件照片", systemImage: "photo")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        photoCanvas
                        controls
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(images.indices, id: \.self) { index in
                                    Button { select(index) } label: {
                                        CardImageView(asset: images[index], pixels: 180).frame(width: 64, height: 46)
                                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(index == selectedIndex ? palette.accent : palette.line, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text("查看第 \(index + 1) 张照片"))
                                    .accessibilityAddTraits(index == selectedIndex ? [.isSelected] : [])
                                }
                            }.padding(2)
                        }
                        .padding(.horizontal, 20).padding(.bottom, 16)
                    }
                }
            }
        }
        .modifier(WalletThemeModifier())
        .frame(width: sheetSize.width, height: sheetSize.height)
    }

    private var photoCanvas: some View {
        GeometryReader { geometry in
            let scale = min(max(zoom * pinch, 1), 4)
            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    CardImageView(asset: images[selectedIndex], pixels: 2400)
                        .frame(width: geometry.size.width * scale, height: geometry.size.height * scale)
                        .id("attachment-photo")
                }
                .onChange(of: zoom) { _, _ in proxy.scrollTo("attachment-photo", anchor: .center) }
            }
            .id(selectedIndex)
            .simultaneousGesture(MagnifyGesture().updating($pinch) { value, state, _ in
                state = value.magnification
            }.onEnded { value in zoom = min(max(zoom * value.magnification, 1), 4) })
            .background(palette.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.line, lineWidth: 1))
        }
        .padding(.horizontal, 20).padding(.top, 18)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button { select(selectedIndex - 1) } label: { Image(systemName: "chevron.left") }
                .disabled(selectedIndex == 0).help("上一张照片").accessibilityLabel("上一张照片")
                .keyboardShortcut(.leftArrow, modifiers: [])
            Text("\(selectedIndex + 1) / \(images.count)").font(.caption).monospacedDigit()
            Button { select(selectedIndex + 1) } label: { Image(systemName: "chevron.right") }
                .disabled(selectedIndex == images.count - 1).help("下一张照片").accessibilityLabel("下一张照片")
                .keyboardShortcut(.rightArrow, modifiers: [])
            Spacer()
            Button { zoom = max(1, zoom - 0.5) } label: { Image(systemName: "minus.magnifyingglass") }
                .disabled(zoom <= 1).help("缩小").accessibilityLabel("缩小")
            Text("\(Int(zoom * 100))%").font(.caption).monospacedDigit().frame(width: 40)
            Button { zoom = min(4, zoom + 0.5) } label: { Image(systemName: "plus.magnifyingglass") }
                .disabled(zoom >= 4).help("放大").accessibilityLabel("放大")
            Button("适应窗口") { zoom = 1 }.disabled(zoom == 1)
        }
        .buttonStyle(.borderless).padding(.horizontal, 22).padding(.vertical, 14)
    }

    private func select(_ index: Int) {
        guard images.indices.contains(index) else { return }
        selectedIndex = index
        zoom = 1
    }
}
