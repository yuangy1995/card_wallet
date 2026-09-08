import SwiftUI

public struct LockScreenView: View {
    @State private var passwordInput = ""
    @State private var showingPasswordRecovery = false
    @State private var errorText = ""
    @State private var supportsTouchID = false
    @FocusState private var passwordFocused: Bool
    @Environment(\.walletPalette) private var palette
    @Environment(\.walletAnimation) private var animation

    public var body: some View {
        ZStack {
            WalletBackground(palette: palette)
            VStack(spacing: 22) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 35, weight: .light))
                    .foregroundStyle(palette.accent)
                    .frame(width: 76, height: 76)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 23))
                VStack(spacing: 8) {
                    Text("卡包已锁定").font(.system(size: 26, weight: .semibold))
                    Text("每张卡，安心收好。").font(.subheadline).foregroundStyle(.secondary)
                }
                if AutoLockManager.shared.credentialAccessFailed {
                    Text("还未能读取已有密码。首次升级需要允许系统读取旧密码，转入本地后不再重复申请。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("重新读取已有密码") { AutoLockManager.shared.retryCredentialAccess() }
                }
                if supportsTouchID {
                    Button {
                        AutoLockManager.shared.evaluateTouchID { success in
                            if !success { errorText = String(localized: "验证未完成，也可以使用密码解锁。") }
                        }
                    } label: {
                        Label("使用 Touch ID", systemImage: "touchid").frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
                VStack(spacing: 12) {
                    SecureField("解锁密码", text: $passwordInput)
                        .textFieldStyle(.roundedBorder).controlSize(.large)
                        .focused($passwordFocused).onSubmit(unlock)
                    if !errorText.isEmpty {
                        Text(errorText).font(.caption).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(action: unlock) { Text("解锁卡包").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(passwordInput.isEmpty)
                }
                Button("忘记密码？") { showingPasswordRecovery = true }.buttonStyle(.borderless)
                Divider()
                Button { NSApplication.shared.terminate(nil) } label: { Label("退出卡包", systemImage: "power") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).font(.caption)
            }
            .padding(30)
            .frame(width: 350)
            .modifier(WalletGlass())
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(palette.edge, lineWidth: 1))
        }
        .onAppear {
            supportsTouchID = AutoLockManager.shared.isTouchIDAvailable
            passwordFocused = true
        }
        .onChange(of: passwordInput) { _, _ in errorText = "" }
        .animation(animation, value: errorText.isEmpty)
        .sheet(isPresented: $showingPasswordRecovery) {
            MacPasswordRecoveryView { showingPasswordRecovery = false }
                .modifier(WalletThemeModifier())
        }
    }

    private func unlock() {
        guard !passwordInput.isEmpty else { return }
        if AutoLockManager.shared.unlock(password: passwordInput) {
            passwordInput = ""
            errorText = ""
        } else {
            errorText = String(localized: "未能解锁，请检查密码，并允许系统读取已保存的密码。")
            passwordFocused = true
        }
    }
}

private enum MacRecoveryAnswerKind {
    case digits
    case expiry
}

private struct MacRecoveryQuestion: Identifiable {
    let id = UUID()
    let prompt: String
    let placeholder: String
    let kind: MacRecoveryAnswerKind
    let acceptedAnswers: Set<String>
}

private struct MacPasswordRecoveryView: View {
    let onRecovered: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var questions: [MacRecoveryQuestion] = []
    @State private var answers = ["", "", ""]
    @State private var verified = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "lock.rotation")
                    .font(.title2)
                    .foregroundColor(.cyan)
                VStack(alignment: .leading) {
                    Text("找回密码")
                        .font(.title2)
                        .bold()
                    Text(verified ? "身份验证已通过，请设置新密码" : "回答基于本机卡包数据生成的验证问题")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if !verified {
                if questions.count == 3 {
                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("问题 \(index + 1)：\(question.prompt)")
                                .font(.system(size: 13, weight: .semibold))
                            SecureField(question.placeholder, text: $answers[index])
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "无法生成验证问题",
                        systemImage: "exclamationmark.shield",
                        description: Text(errorText.isEmpty ? "卡片信息不足，请确认已保存卡号、CVV/有效期和信用额度。" : errorText)
                    )
                }
            } else {
                SecureField("至少 6 位新密码", text: $newPassword)
                    .textFieldStyle(.roundedBorder)
                SecureField("再次输入新密码", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)
            }

            if !errorText.isEmpty && questions.count == 3 {
                Text(errorText)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            HStack {
                Button("取消") { dismiss() }
                Spacer()
                if verified {
                    Button("设置并解锁") { saveNewPassword() }
                        .buttonStyle(.borderedProminent)
                        .disabled(newPassword.count < 6 || confirmPassword.isEmpty)
                } else {
                    Button("验证答案") { verifyAnswers() }
                        .buttonStyle(.borderedProminent)
                        .disabled(questions.count != 3 || answers.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }))
                }
            }
        }
        .padding(24)
        .frame(width: 520, height: 500)
        .onAppear(perform: loadQuestions)
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

        let detailQuestion: MacRecoveryQuestion?
        if let card = cards.first(where: { !normalize($0.cvv ?? "", kind: .digits).isEmpty }) {
            detailQuestion = MacRecoveryQuestion(
                prompt: "请输入尾号 \(String(card.cardNumber.filter(\.isNumber).suffix(4))) 卡片的 CVV",
                placeholder: "CVV",
                kind: .digits,
                acceptedAnswers: [normalize(card.cvv ?? "", kind: .digits)]
            )
        } else if let card = cards.first(where: { !normalize($0.valid ?? "", kind: .expiry).isEmpty }) {
            detailQuestion = MacRecoveryQuestion(
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
            MacRecoveryQuestion(
                prompt: "请输入当前卡包中任意一张卡片的完整卡号",
                placeholder: "完整卡号",
                kind: .digits,
                acceptedAnswers: cardNumbers
            ),
            detailQuestion,
            MacRecoveryQuestion(
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
        guard newPassword.count >= 6 else {
            errorText = "新密码至少需要 6 位。"
            return
        }
        guard newPassword == confirmPassword else {
            errorText = "两次输入的新密码不一致。"
            return
        }
        guard AutoLockManager.shared.setPassword(newPassword) else {
            errorText = String(localized: "新密码未保存，请检查密码存储权限后重试。")
            return
        }
        _ = AutoLockManager.shared.unlock(password: newPassword)
        onRecovered()
        dismiss()
    }

    private func normalize(_ value: String, kind: MacRecoveryAnswerKind) -> String {
        switch kind {
        case .digits, .expiry:
            return String(value.filter(\.isNumber))
        }
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
