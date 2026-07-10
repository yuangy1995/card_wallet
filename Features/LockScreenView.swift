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
    @State private var showingPasswordRecovery = false

    private var passwordLength: Int {
        let saved = KeychainManager.load(key: "app_lock_password") ?? ""
        return saved.isEmpty ? 6 : saved.count
    }

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
                    .fill(Color.blue.opacity(0.15))
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

                    Button("忘记密码？通过卡片信息验证") {
                        showingPasswordRecovery = true
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            let savedPassword = KeychainManager.load(key: "app_lock_password") ?? ""
            if savedPassword.isEmpty {
                UserDefaults.standard.set(false, forKey: "app_lock_enabled")
                lockManager.unlock()
                return
            }
            startAnimations()
            if biometricAvailable() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tryBiometricAuth()
                }
            }
        }
        .sheet(isPresented: $showingPasswordRecovery) {
            IOSPasswordRecoveryView {
                showingPasswordRecovery = false
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
                        colors: [.blue, .purple, .blue, .blue],
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
                .shadow(color: Color.blue.opacity(0.3), radius: 12, x: 0, y: 0)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .white.opacity(0.9)],
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
                ForEach(0..<passwordLength, id: \.self) { index in
                    Circle()
                        .fill(index < passwordInput.count ? Color.blue : Color.white.opacity(0.3))
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
            let length = passwordLength
            guard passwordInput.count < length else { return }
            withAnimation(.spring(duration: 0.1)) { passwordInput += label }
            if passwordInput.count == length { verifyPassword() }
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

private enum IOSRecoveryAnswerKind {
    case digits
    case expiry
}

private struct IOSRecoveryQuestion: Identifiable {
    let id = UUID()
    let prompt: String
    let placeholder: String
    let kind: IOSRecoveryAnswerKind
    let acceptedAnswers: Set<String>
}

private struct IOSPasswordRecoveryView: View {
    let onRecovered: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var questions: [IOSRecoveryQuestion] = []
    @State private var answers = ["", "", ""]
    @State private var verified = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(
                        verified ? "身份验证已通过，请设置新密码" : "请回答三项本机卡片信息",
                        systemImage: verified ? "checkmark.shield.fill" : "lock.rotation"
                    )
                    .foregroundStyle(verified ? .green : .blue)
                } footer: {
                    Text("验证仅在本机完成，答案不会保存或上传。")
                }

                if verified {
                    Section("设置新密码") {
                        SecureField("至少 4 位数字", text: $newPassword)
                            .keyboardType(.numberPad)
                        SecureField("再次输入新密码", text: $confirmPassword)
                            .keyboardType(.numberPad)
                    }
                } else if questions.count == 3 {
                    Section("身份验证") {
                        ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("问题 \(index + 1)：\(question.prompt)")
                                    .font(.system(size: 14, weight: .semibold))
                                SecureField(question.placeholder, text: $answers[index])
                                    .keyboardType(.numberPad)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                } else {
                    Section {
                        ContentUnavailableView(
                            "无法生成验证问题",
                            systemImage: "exclamationmark.shield",
                            description: Text(errorText.isEmpty ? "卡片信息不足，请确认已保存卡号、CVV/有效期和信用额度。" : errorText)
                        )
                    }
                }

                if !errorText.isEmpty && questions.count == 3 {
                    Section {
                        Label(errorText, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if verified {
                        Button("设置并解锁") { saveNewPassword() }
                            .disabled(newPassword.count < 4 || confirmPassword.isEmpty)
                    } else {
                        Button("验证") { verifyAnswers() }
                            .disabled(questions.count != 3 || answers.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }))
                    }
                }
            }
            .onAppear(perform: loadQuestions)
        }
    }

    private func loadQuestions() {
        guard case .success(let cards) = LocalStorageManager.read(), !cards.isEmpty else {
            errorText = "没有找到可用于验证的本机卡片数据。"
            return
        }

        let cardNumbers = Set(cards.map { normalize($0.cardNumber, kind: .digits) }.filter { !$0.isEmpty })
        guard !cardNumbers.isEmpty else {
            errorText = "卡包中没有完整卡号，无法验证身份。"
            return
        }

        let detailQuestion: IOSRecoveryQuestion?
        if let card = cards.first(where: { !normalize($0.cvv ?? "", kind: .digits).isEmpty }) {
            detailQuestion = IOSRecoveryQuestion(
                prompt: "请输入尾号 \(String(card.cardNumber.filter(\.isNumber).suffix(4))) 卡片的 CVV",
                placeholder: "CVV",
                kind: .digits,
                acceptedAnswers: [normalize(card.cvv ?? "", kind: .digits)]
            )
        } else if let card = cards.first(where: { !normalize($0.valid ?? "", kind: .expiry).isEmpty }) {
            detailQuestion = IOSRecoveryQuestion(
                prompt: "请输入尾号 \(String(card.cardNumber.filter(\.isNumber).suffix(4))) 卡片的有效期",
                placeholder: "MM/YY",
                kind: .expiry,
                acceptedAnswers: [normalize(card.valid ?? "", kind: .expiry)]
            )
        } else {
            detailQuestion = nil
        }

        guard let detailQuestion,
              let limitCard = cards.first(where: { $0.cardCategory != "debit" && ($0.limit ?? 0) > 0 }) else {
            errorText = "卡片的 CVV/有效期或信用额度信息不足。"
            return
        }

        let displayName = [limitCard.bank, limitCard.alias ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
        questions = [
            IOSRecoveryQuestion(
                prompt: "请输入当前卡包中任意一张卡片的完整卡号",
                placeholder: "完整卡号",
                kind: .digits,
                acceptedAnswers: cardNumbers
            ),
            detailQuestion,
            IOSRecoveryQuestion(
                prompt: "\(displayName) 的信用额度是多少？",
                placeholder: "纯数字金额",
                kind: .digits,
                acceptedAnswers: [String(Int((limitCard.limit ?? 0).rounded()))]
            )
        ]
        errorText = ""
    }

    private func verifyAnswers() {
        let allCorrect = zip(questions, answers).allSatisfy { question, answer in
            question.acceptedAnswers.contains(normalize(answer, kind: question.kind))
        }
        if allCorrect {
            errorText = ""
            verified = true
        } else {
            errorText = "验证答案不正确，请检查后重试。"
        }
    }

    private func saveNewPassword() {
        let normalizedPassword = String(newPassword.filter(\.isNumber))
        guard normalizedPassword == newPassword, normalizedPassword.count >= 4 else {
            errorText = "新密码至少需要 4 位数字。"
            return
        }
        guard newPassword == confirmPassword else {
            errorText = "两次输入的新密码不一致。"
            return
        }
        KeychainManager.save(key: "app_lock_password", value: newPassword)
        UserDefaults.standard.set(true, forKey: "app_lock_enabled")
        AutoLockManager.shared.unlock()
        onRecovered()
        dismiss()
    }

    private func normalize(_ value: String, kind: IOSRecoveryAnswerKind) -> String {
        switch kind {
        case .digits, .expiry:
            return String(value.filter(\.isNumber))
        }
    }
}
