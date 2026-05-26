import SwiftUI

public struct LockScreenView: View {
    @State private var passwordInput = ""
    @State private var showingError = false
    
    // 指纹图标呼吸动画
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.5
    
    public var body: some View {
        ZStack {
            // 1. 系统级强磨砂玻璃防窥罩 (Apple ultraThinMaterial)
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            // 2. 暗色微弱发光的科技感星空背景 (自适应暗度)
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 顶部锁孔状态
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cyan, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .purple.opacity(0.3), radius: 8)
                    
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
                
                // 下部：密码输入框与错误反馈
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        SecureField("输入应用安全解锁密码", text: $passwordInput)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(showingError ? Color.red : Color.primary.opacity(0.15), lineWidth: 1.5)
                            )
                            .frame(width: 180)
                            .onSubmit {
                                executePasswordUnlock()
                            }
                        
                        Button("解锁") {
                            executePasswordUnlock()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                    }
                    
                    if showingError {
                        Text("❌ 解锁密码错误，请检查后重新输入")
                            .font(.caption)
                            .foregroundColor(.red)
                            .transition(.shake) // 平滑抖动提示
                    }
                }
                
                // 最底部：一键退出卡包应用，符合HIG逻辑
                Button(action: exitApp) {
                    Text("安全退出系统")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                        .underline()
                }
                .buttonStyle(.plain)
            }
            .frame(width: 300, height: 360)
            .padding(24)
            .background(.thinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 20)
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
