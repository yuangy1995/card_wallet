import SwiftUI

public enum NavigationSection: Hashable {
    case allCards
    case annualFeeAlert
    case statistics
    case cloudSync
    case settings
}

public struct SidebarView: View {
    @Binding public var selection: NavigationSection?
    public var cards: [SharedCard]
    
    // 💡 监听锁定管理器状态，实现设置修改后侧边栏实时响应
    @State private var lockManager = AutoLockManager.shared
    
    // 💡 锁定按钮悬浮 Hover 状态
    @State private var isLockHovered = false
    
    // 💡 退出按钮悬浮 Hover 状态
    @State private var isQuitHovered = false
    
    // 计算临近年费的卡片数量
    private var annualFeeAlertCount: Int {
        cards.filter { card in
            guard card.isQualified == "2" else { return false } // 只有未达标的才需要提醒
            return DateCalculator.isNearAnnualFeeTimestamp(card.nextAnnualFeeCollectionTime)
        }.count
    }
    
    public init(selection: Binding<NavigationSection?>, cards: [SharedCard]) {
        self._selection = selection
        self.cards = cards
    }
    
    public var body: some View {
        List(selection: $selection) {
            Section(header: Text("导航栏")) {
                NavigationLink(value: NavigationSection.allCards) {
                    Label("所有信用卡", systemImage: "creditcard")
                }
                
                // 💡 智能到期角标：如果真的存在临近卡片，展现惊艳的红色急需角标！
                if annualFeeAlertCount > 0 {
                    NavigationLink(value: NavigationSection.annualFeeAlert) {
                        HStack {
                            Label("临近年费卡", systemImage: "clock.badge.exclamationmark")
                                .foregroundColor(.orange)
                            Spacer()
                            Text("\(annualFeeAlertCount)")
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                NavigationLink(value: NavigationSection.statistics) {
                    Label("统计与分析", systemImage: "chart.pie.fill")
                }
                
                NavigationLink(value: NavigationSection.cloudSync) {
                    Label("云同步", systemImage: "icloud.and.arrow.up.fill")
                }
                
                NavigationLink(value: NavigationSection.settings) {
                    Label("设置", systemImage: "gearshape.2.fill")
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
        // 💡 侧边栏底部提供锁屏及退出App功能，提供磨砂背景与优雅悬浮反馈
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 20) {
                Spacer()
                
                // 💡 仅当用户保存了密码，侧边栏底部才居中浮现主动锁定圆形组件
                if lockManager.hasPassword {
                    Button {
                        lockManager.lock()
                    } label: {
                        ZStack {
                            // 优雅的圆形磨砂背景盘
                            Circle()
                                .fill(isLockHovered ? Color.orange.opacity(0.18) : Color.primary.opacity(0.04))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(isLockHovered ? Color.orange.opacity(0.4) : Color.primary.opacity(0.12), lineWidth: 1)
                                )
                            
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isLockHovered ? .orange : .secondary)
                                .shadow(color: isLockHovered ? .orange.opacity(0.35) : .clear, radius: 4)
                        }
                        .scaleEffect(isLockHovered ? 1.08 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isLockHovered)
                    }
                    .buttonStyle(.plain)
                    .onHover { hover in
                        isLockHovered = hover
                    }
                }
                
                // 💡 退出应用圆形按钮，提供亮丽的红色悬浮警告
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    ZStack {
                        // 优雅的圆形磨砂背景盘
                        Circle()
                            .fill(isQuitHovered ? Color.red.opacity(0.18) : Color.primary.opacity(0.04))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(isQuitHovered ? Color.red.opacity(0.4) : Color.primary.opacity(0.12), lineWidth: 1)
                            )
                        
                        Image(systemName: "power")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isQuitHovered ? .red : .secondary)
                            .shadow(color: isQuitHovered ? .red.opacity(0.35) : .clear, radius: 4)
                    }
                    .scaleEffect(isQuitHovered ? 1.08 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isQuitHovered)
                }
                .buttonStyle(.plain)
                .onHover { hover in
                    isQuitHovered = hover
                }
                
                Spacer()
            }
            .padding(.vertical, 10)
            .background(.thinMaterial) // 自适应窗口毛玻璃
            .overlay(
                VStack {
                    Divider()
                        .opacity(0.3)
                    Spacer()
                }
            )
        }
    }
}
