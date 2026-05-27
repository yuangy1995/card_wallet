import SwiftUI

public struct LockScreenView: View {
    @State private var passwordInput = ""
    @State private var showingError = false
    
    // 指纹图标呼吸动画
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.5
    
    // 💡 盾牌飘浮与背景光环动画状态
    @State private var shieldScale: CGFloat = 1.0
    @State private var shieldOffsetY: CGFloat = 0.0
    @State private var glowRotation: Double = 0.0
    
    // 💡 退出按钮与解锁按钮悬浮 Hover 状态
    @State private var isExitButtonHovered = false
    @State private var isUnlockButtonHovered = false
    
    public var body: some View {
        ZStack {
            // 1. 系统级强磨砂玻璃防窥罩 (Apple ultraThinMaterial)
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            // 2. 暗色微弱发光的科技感星空背景 (自适应暗度)
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            
            // 3. 💡 绚丽的背景霓虹光晕 (Glassmorphism Backing Glow)，溢出磨砂感
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.18))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: -140, y: -120)
                
                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 140, y: 120)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 28) {
                // 顶部锁孔状态与动画盾牌
                VStack(spacing: 12) {
                    ZStack {
                        // 底层流光霓虹圆环 (慢速旋转渐变)
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [.cyan, .purple, .blue, .cyan],
                                    center: .center
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 66, height: 66)
                            .rotationEffect(.degrees(glowRotation))
                            .blur(radius: 1.5)
                            .opacity(0.7)
                            .scaleEffect(shieldScale * 1.1)
                        
                        // 软晕阴影环
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.purple.opacity(0.18), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 36
                                )
                            )
                            .frame(width: 74, height: 74)
                            .scaleEffect(shieldScale)
                        
                        // 盾牌主体 (带浮动与精致阴影)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 46))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.cyan, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .purple.opacity(0.4), radius: 10)
                            .scaleEffect(shieldScale)
                            .offset(y: shieldOffsetY)
                    }
                    .frame(width: 80, height: 80)
                    .padding(.bottom, 4)
                    
                    Text("系统处于安全保护状态")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.primary)
                    
                    Text("防窥护盾已启动，请认证以继续操作")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if AutoLockManager.shared.isTouchIDAvailable {
                    // 中部：呼吸指纹 Touch ID 秒级解锁标
                    Button(action: triggerTouchID) {
                        ZStack {
                            // 霓虹呼吸外环
                            Circle()
                                .stroke(
                                    LinearGradient(colors: [Color.cyan, Color.purple], startPoint: .top, endPoint: .bottom),
                                    lineWidth: 2
                                )
                                .frame(width: 70, height: 70)
                                .scaleEffect(ringScale)
                                .opacity(ringOpacity)
                            
                            Circle()
                                .fill(Color.primary.opacity(0.06))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
                                )
                            
                            Image(systemName: "touchid")
                                .font(.system(size: 30))
                                .foregroundColor(.cyan)
                                .shadow(color: .cyan.opacity(0.6), radius: 6)
                        }
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        startBreathingAnimation()
                    }
                    
                    // 💡 提示用户手动点击指纹图标唤起硬件解锁，优雅引导
                    Text("💡 点击上方指纹图标以唤起 Touch ID 解锁")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.top, -8)
                }
                
                // 下部：精美密码输入栏与提交微缩放
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            SecureField("输入应用安全解锁密码", text: $passwordInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(showingError ? Color.red : Color.primary.opacity(0.12), lineWidth: 1.5)
                        )
                        .frame(width: 190)
                        .onSubmit {
                            executePasswordUnlock()
                        }
                        
                        Button {
                            executePasswordUnlock()
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.cyan)
                                .shadow(color: .cyan.opacity(0.3), radius: 4)
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(isUnlockButtonHovered ? 1.1 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isUnlockButtonHovered)
                        .onHover { hover in
                            isUnlockButtonHovered = hover
                        }
                    }
                    
                    if showingError {
                        Text("❌ 解锁密码错误，请检查后重新输入")
                            .font(.caption)
                            .foregroundColor(.red)
                            .transition(.shake) // 平滑抖动提示
                    }
                }
                
                // 最底部：精致红色发光安全退出胶囊按钮，符合HIG逻辑
                Button(action: exitApp) {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .bold))
                        Text("安全退出")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(isExitButtonHovered ? .white : .red.opacity(0.85))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isExitButtonHovered ? Color.red.opacity(0.85) : Color.red.opacity(0.06))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isExitButtonHovered ? Color.red.opacity(0.9) : Color.red.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: isExitButtonHovered ? Color.red.opacity(0.3) : Color.clear, radius: 6)
                    .scaleEffect(isExitButtonHovered ? 1.05 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isExitButtonHovered)
                }
                .buttonStyle(.plain)
                .onHover { hover in
                    isExitButtonHovered = hover
                }
            }
            .frame(width: 320)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.4), Color.purple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 25)
            .onAppear {
                startShieldAnimation()
            }
        }
    }
    
    private func startBreathingAnimation() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            ringScale = 1.15
            ringOpacity = 0.8
        }
    }
    
    private func startShieldAnimation() {
        // 呼吸浮动动效
        withAnimation(
            .easeInOut(duration: 2.2)
            .repeatForever(autoreverses: true)
        ) {
            shieldScale = 1.06
            shieldOffsetY = -5.0
        }
        
        // 慢速流光旋转
        withAnimation(
            .linear(duration: 8.0)
            .repeatForever(autoreverses: false)
        ) {
            glowRotation = 360.0
        }
    }
    
    private func triggerTouchID() {
        AutoLockManager.shared.evaluateTouchID { success in
            if !success {
                // 如果指纹失败，静默降级到密码输入，不影响交互
                print("Touch ID 解锁未成功")
            }
        }
    }
    
    private func executePasswordUnlock() {
        if AutoLockManager.shared.unlock(password: passwordInput) {
            showingError = false
        } else {
            withAnimation(.default) {
                showingError = true
            }
            // 2秒后自动清除错误状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.showingError = false
            }
        }
    }
    
    private func exitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// 经典的密码错误抖动动画修饰符 (Shake Animation)
extension AnyTransition {
    static var shake: AnyTransition {
        .modifier(
            active: ShakeEffect(animatableData: 1),
            identity: ShakeEffect(animatableData: 0)
        )
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: 10 * sin(animatableData * .pi * 4),
                y: 0
            )
        )
    }
}
