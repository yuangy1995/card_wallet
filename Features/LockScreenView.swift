import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    @StateObject private var lockManager = AutoLockManager.shared
    @State private var passwordInput = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var shieldScale: CGFloat = 1.0
    @State private var shieldOffsetY: CGFloat = 0.0
    @State private var glowRotation: Double = 0.0
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.5
    @State private var attemptBiometric = false

    var body: some View {
        ZStack {
            // 1. 极深暗色毛玻璃背景
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // 2. 背景霓虹光晕
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .offset(x: -130, y: -130)
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 70)
                    .offset(x: 130, y: 130)
            }
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // 3. 动效安全盾
                shieldView

                // 4. 标题
                VStack(spacing: 8) {
                    Text("应用已锁定")
                        .font(.system(.title2, weight: .bold))
                        .foregroundColor(.white)
                    Text("请验证身份以继续使用")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }

                // 5. 密码输入（点阵 PIN 风格）
                pinInputArea

                // 错误提示
                if showingError {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.red)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                Spacer()

                // 6. 底部操作
                VStack(spacing: 12) {
                    if biometricAvailable() {
                        Button {
                            tryBiometricAuth()
                        } label: {
                            Label(biometricTypeLabel(), systemImage: biometricIcon())
                                .font(.system(.callout, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.15), in: Capsule())
                                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            startAnimations()
            if biometricAvailable() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tryBiometricAuth()
                }
            }
        }
    }

    // MARK: - 盾牌动效
    private var shieldView: some View {
        ZStack {
            // 旋转光晕环
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .purple, .blue, .cyan],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(glowRotation))

            // 外环脉冲
            Circle()
                .stroke(Color.white.opacity(ringOpacity), lineWidth: 1.5)
                .frame(width: 76, height: 76)
                .scaleEffect(ringScale)

            // 毛玻璃背景圆
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 64, height: 64)
                .shadow(color: Color.cyan.opacity(0.3), radius: 12, x: 0, y: 0)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .white.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .offset(y: shieldOffsetY)
        .scaleEffect(shieldScale)
    }

    // MARK: - PIN 输入区
    private var pinInputArea: some View {
        VStack(spacing: 16) {
            // 点阵显示
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(index < passwordInput.count ? Color.cyan : Color.white.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .scaleEffect(index < passwordInput.count ? 1.2 : 1.0)
                        .animation(.spring(duration: 0.2), value: passwordInput.count)
                }
            }
            .padding(.vertical, 8)

            // 数字键盘
            VStack(spacing: 12) {
                ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                    HStack(spacing: 20) {
                        ForEach(row, id: \.self) { num in
                            pinButton(String(num))
                        }
                    }
                }
                HStack(spacing: 20) {
                    // 清空
                    Button {
                        withAnimation { passwordInput = "" }
                    } label: {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.1)).frame(width: 64, height: 64)
                            Text("清空").font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.7))
                        }
                    }
                    pinButton("0")
                    // 删除
                    Button {
                        if !passwordInput.isEmpty {
                            _ = withAnimation { passwordInput.removeLast() }
                        }
                    } label: {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.1)).frame(width: 64, height: 64)
                            Image(systemName: "delete.left.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
    }

    private func pinButton(_ label: String) -> some View {
        Button {
            guard passwordInput.count < 6 else { return }
            withAnimation(.spring(duration: 0.1)) { passwordInput += label }
            if passwordInput.count == 6 { verifyPassword() }
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                Text(label)
                    .font(.system(.title2, design: .rounded, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 动画
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            shieldOffsetY = -8
            shieldScale = 1.05
        }
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            glowRotation = 360
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            ringScale = 1.15
            ringOpacity = 0.0
        }
    }

    // MARK: - 验证
    private func verifyPassword() {
        let savedPassword = KeychainManager.load(key: "app_lock_password") ?? ""
        if passwordInput == savedPassword {
            withAnimation { lockManager.unlock() }
        } else {
            withAnimation {
                showingError = true
                errorMessage = "密码错误，请重试"
                passwordInput = ""
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showingError = false }
            }
        }
    }

    private func tryBiometricAuth() {
        guard UserDefaults.standard.bool(forKey: "enable_face_id") else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return }
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "验证身份以访问卡包"
        ) { success, _ in
            if success {
                Task { @MainActor in
                    withAnimation { lockManager.unlock() }
                }
            }
        }
    }

    private func biometricAvailable() -> Bool {
        guard UserDefaults.standard.bool(forKey: "enable_face_id") else { return false }
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    private func biometricTypeLabel() -> String {
        let context = LAContext()
        return context.biometryType == .faceID ? "使用 Face ID 解锁" : "使用 Touch ID 解锁"
    }

    private func biometricIcon() -> String {
        let context = LAContext()
        return context.biometryType == .faceID ? "faceid" : "touchid"
    }
}
