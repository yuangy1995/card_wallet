import SwiftUI
import LocalAuthentication

public struct SettingsView: View {
    // 💡 敏感安全凭证存储介质
    @State private var securityStorageMode = KeychainManager.currentStorageMode
    @State private var storageMigrationStatusText = ""
    @State private var storageMigrationSuccess = true
    
    // 💡 隐私安全卡片聚合与高阶动效控制
    @State private var isEditingSecurity = false
    @State private var isSecurityPulseAnimating = false
    
    // 密码锁设置
    @State private var lockPassword = ""
    @State private var isLockEnabled = false
    @State private var passwordStatusText = ""
    
    public var body: some View {
        Form {
            // Section 4: 🛡️ 全方位隐私安全与凭证保护 (锁屏防窥与凭证存储二合一，高级呼吸动效安心 UI)
            Section(header: HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                Text("全方位隐私安全与凭证保护")
            }) {
                if !isEditingSecurity {
                    // 💡 安心状态下的高阶原生 UI & 呼吸光环波纹动效
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 20) {
                            // 左侧：呼吸光环安全盾动效
                            ZStack {
                                // 呼吸波动外环 2
                                Circle()
                                    .stroke(Color.green.opacity(0.15), lineWidth: 2)
                                    .frame(width: 60, height: 60)
                                    .scaleEffect(isSecurityPulseAnimating ? 1.25 : 0.95)
                                    .opacity(isSecurityPulseAnimating ? 0.0 : 0.8)
                                
                                // 呼吸波动外环 1
                                Circle()
                                    .fill(Color.green.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                    .scaleEffect(isSecurityPulseAnimating ? 1.15 : 0.98)
                                
                                // 中心防线主盾 (绿色-青色渐变，极佳科技拟物感)
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green.opacity(0.85), Color.cyan.opacity(0.85)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                    .shadow(color: Color.green.opacity(0.3), radius: 6, x: 0, y: 3)
                                
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 65, height: 65)
                            .onAppear {
                                // 💡 启用优雅的呼吸微动画
                                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                    isSecurityPulseAnimating = true
                                }
                            }
                            
                            // 右侧：核心提示与防线评级
                            VStack(alignment: .leading, spacing: 4) {
                                Text("本地隐私安全防护已全面就绪")
                                    .font(.system(.subheadline, design: .rounded))
                                    .bold()
                                    .foregroundColor(.primary)
                                
                                let levelText = isLockEnabled ? "指纹或密码保护" : "本机加密保存"
                                Text("防护级别：\(levelText)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isLockEnabled ? .green : .orange)
                                
                                Text("您的卡号、CVV 和同步密码会加密保存在本机。")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 6)
                        
                        Divider()
                            .opacity(0.5)
                        
                        // 细分防护状态列表
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                Image(systemName: isLockEnabled ? "lock.fill" : "lock.open.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(isLockEnabled ? .green : .orange)
                                    .frame(width: 14, alignment: .center)
                                
                                Text("自动闲置防窥锁屏:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                
                                Text(isLockEnabled ? "已启用" : "未开启 (建议前往配置以防窥)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isLockEnabled ? .green : .orange)
                            }
                            
                            if AutoLockManager.shared.isTouchIDAvailable {
                                HStack(spacing: 12) {
                                    Image(systemName: "faceid")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                        .frame(width: 14, alignment: .center)
                                    
                                    Text("生物特征硬件防护:")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    
                                    Text("Touch ID 解锁已开启")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                    .frame(width: 14, alignment: .center)
                                
                                Text("机密存储模式介质:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                
                                Text(securityStorageMode.displayName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isEditingSecurity = true
                                }
                            }) {
                                Label("调整隐私安全策略", systemImage: "slider.horizontal.3")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.015))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                } else {
                    // 💡 卡片内嵌策略编辑模式 (平滑过渡)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.green)
                                Text("配置您的本地数据防护策略")
                            }
                                .font(.system(.subheadline, design: .rounded))
                                .bold()
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        // 1. 防窥锁屏配置子模块
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle("开启闲置/后台自动防窥锁屏", isOn: $isLockEnabled)
                                    .onChange(of: isLockEnabled) { _, newValue in
                                        if !newValue {
                                            AutoLockManager.shared.removePassword()
                                            lockPassword = ""
                                            withAnimation {
                                                passwordStatusText = "⚠️ 防窥锁屏密码已安全清除。"
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                                withAnimation {
                                                    passwordStatusText = ""
                                                }
                                            }
                                        } else {
                                            if AutoLockManager.shared.hasPassword {
                                                lockPassword = "••••••"
                                            }
                                        }
                                    }
                            }
                            
                            if isLockEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        SecureField(AutoLockManager.shared.hasPassword ? "••••••" : "输入本地锁屏保护密码", text: $lockPassword)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 180)
                                        
                                        Button("确定设置") {
                                            if !lockPassword.isEmpty && lockPassword != "••••••" {
                                                AutoLockManager.shared.setPassword(lockPassword)
                                                withAnimation {
                                                    passwordStatusText = "✅ 锁屏密码已启用并受硬件保护！"
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                                    withAnimation {
                                                        passwordStatusText = ""
                                                    }
                                                }
                                            } else if lockPassword == "••••••" {
                                                withAnimation {
                                                    passwordStatusText = "✅ 密码已处于锁定保护中，无需修改。"
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                                    withAnimation {
                                                        passwordStatusText = ""
                                                    }
                                                }
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(lockPassword.isEmpty)
                                    }
                                    
                                    if !passwordStatusText.isEmpty {
                                        Text(passwordStatusText)
                                            .font(.system(size: 10))
                                            .foregroundColor(passwordStatusText.contains("✅") ? .green : .orange)
                                            .transition(.opacity)
                                    }
                                }
                                .padding(.leading, 8)
                                .transition(.slide)
                            }
                        }
                        
                        Divider()
                            .opacity(0.3)
                        
                        // 2. 凭证存储介质配置子模块
                        VStack(alignment: .leading, spacing: 8) {
                            Text("机密凭证存储介质：")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Picker("凭证存储介质", selection: $securityStorageMode) {
                                ForEach(KeychainManager.SecurityStorageMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: securityStorageMode) { _, newMode in
                                triggerStorageModeMigration(newMode)
                            }
                            
                            if !storageMigrationStatusText.isEmpty {
                                Text(storageMigrationStatusText)
                                    .font(.system(size: 10))
                                    .foregroundColor(storageMigrationSuccess ? .green : .red)
                                    .transition(.opacity)
                            }
                            
                            Text("说明：如果系统经常弹出钥匙串授权提示，建议选择 [应用内部加密存储]。这样可以减少系统密码弹窗，同时仍会加密保存您的同步账号。")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.8))
                                .lineSpacing(2)
                        }
                        
                        Divider()
                            .opacity(0.3)
                        
                        HStack {
                            if AutoLockManager.shared.isTouchIDAvailable {
                                Text("🔒 当前设备支持 Touch ID 解锁")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("保存并开启安全防护") {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isEditingSecurity = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                    }
                    .padding(14)
                    .background(Color.primary.opacity(0.015))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            isLockEnabled = AutoLockManager.shared.hasPassword
            if isLockEnabled {
                lockPassword = "••••••"
            }
        }
    }
    
    private func triggerStorageModeMigration(_ newMode: KeychainManager.SecurityStorageMode) {
        let success = KeychainManager.migrate(to: newMode)
        withAnimation {
            storageMigrationSuccess = success
            if success {
                storageMigrationStatusText = "✅ 安全凭据已成功双向热迁移至 [\(newMode.displayName)]！"
            } else {
                storageMigrationStatusText = "❌ 迁移安全凭据失败，请检查系统钥匙串权限"
            }
        }
        // 3秒后自动淡出
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                storageMigrationStatusText = ""
            }
        }
    }
}
