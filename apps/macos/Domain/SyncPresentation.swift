import Foundation

enum WalletSyncState: Equatable {
    case disabled, unconfigured, syncing, pending, attention, completed, ready

    static func resolve(enabled: Bool, syncing: Bool, message: String, latestStatus: String?, lastSuccess: Date?) -> Self {
        if syncing { return .syncing }
        if !enabled { return .disabled }
        if message.contains("未设置") { return .unconfigured }
        if message.contains("新修改") || message.contains("继续上传") { return .pending }
        if message.contains("密钥") || message.contains("还没有新版") || latestStatus == "error" || latestStatus == "warning" { return .attention }
        if lastSuccess != nil || latestStatus == "success" { return .completed }
        return .ready
    }

    var title: String {
        switch self {
        case .disabled: return String(localized: "云盘同步已关闭")
        case .unconfigured: return String(localized: "还未连接云盘")
        case .syncing: return String(localized: "正在同步卡片")
        case .pending: return String(localized: "还有更改等待同步")
        case .attention: return String(localized: "同步需要处理")
        case .completed: return String(localized: "上次同步已完成")
        case .ready: return String(localized: "准备同步")
        }
    }
    var detail: String {
        switch self {
        case .disabled: return String(localized: "可以继续管理本机卡片，在同步设置中重新开启。")
        case .unconfigured: return String(localized: "连接已有云盘，让各设备上的卡片保持一致。")
        case .syncing: return String(localized: "后台同步中，可以继续浏览和编辑卡片。")
        case .pending: return String(localized: "新的修改已保存在本机，将继续上传到云端。")
        case .attention: return String(localized: "请检查云盘连接和同步密钥。本机卡片仍保留。")
        case .completed: return String(localized: "在下方查看本次文件读写与具体卡片变化。")
        case .ready: return String(localized: "尚未确认同步结果，可以立即检查云端。")
        }
    }
    var icon: String {
        switch self {
        case .disabled: return "icloud.slash"
        case .unconfigured: return "icloud"
        case .syncing, .pending: return "arrow.triangle.2.circlepath"
        case .attention: return "exclamationmark.icloud"
        case .completed: return "checkmark.icloud"
        case .ready: return "icloud.and.arrow.up"
        }
    }

    static func safeValue(label: String, value: String) -> String {
        if label.contains("安全码") || label.uppercased().contains("CVV") { return value.isEmpty ? String(localized: "未填写") : "•••" }
        if label.contains("卡号") { return value.isEmpty ? String(localized: "未填写") : "•••• " + String(value.suffix(4)) }
        return value.isEmpty ? String(localized: "未填写") : value
    }
}
