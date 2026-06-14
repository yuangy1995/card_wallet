import SwiftUI

struct StorageManagementView: View {
    @State private var cardsSize: Int64 = 0
    @State private var ledgerSize: Int64 = 0
    @State private var diagnosticsSize: Int64 = 0
    @State private var cacheSize: Int64 = 0
    
    @State private var cloudSizes: [String: Int64] = [:]
    @State private var isFetchingCloud = false
    @State private var cloudError: String? = nil
    
    @State private var isCalculating = false
    @State private var isClearing = false
    @State private var showClearAlert = false
    @State private var showSuccessToast = false
    
    var body: some View {
        Form {
            Section(header: Text("数据占用")) {
                HStack {
                    Label("卡片数据", systemImage: "creditcard.fill")
                    Spacer()
                    if isCalculating {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text(formatSize(cardsSize))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Label("同步账本", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    if isCalculating {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text(formatSize(ledgerSize))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("云端资源占用")) {
                if isFetchingCloud {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("正在获取云端空间占用...")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } else if let error = cloudError {
                    if error == "未配置云端同步" {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label("云端同步未配置", systemImage: "icloud.slash")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            Text("您可以在设置中配置 WebDAV 云端同步，配置后即可查看云端空间占用。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("云端获取失败", systemImage: "exclamationmark.icloud.fill")
                                    .foregroundColor(.orange)
                                Spacer()
                                Button(action: fetchCloudSizes) {
                                    Text("重试")
                                        .font(.subheadline)
                                        .bold()
                                }
                            }
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    if cloudSizes.values.reduce(0, +) == 0 {
                        HStack {
                            Spacer()
                            Text("暂无云端备份文件")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    } else {
                        if let iosSize = cloudSizes["iOS"], iosSize > 0 {
                            HStack {
                                Label("iOS 端占用", systemImage: "iphone")
                                Spacer()
                                Text(formatSize(iosSize))
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let macSize = cloudSizes["Mac"], macSize > 0 {
                            HStack {
                                Label("Mac 端占用", systemImage: "macbook")
                                Spacer()
                                Text(formatSize(macSize))
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let webSize = cloudSizes["Web"], webSize > 0 {
                            HStack {
                                Label("Web 端占用", systemImage: "safari.fill")
                                Spacer()
                                Text(formatSize(webSize))
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let androidSize = cloudSizes["Android"], androidSize > 0 {
                            HStack {
                                Label("Android 端占用", systemImage: "phone.fill")
                                Spacer()
                                Text(formatSize(androidSize))
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let otherSize = cloudSizes["Other"], otherSize > 0 {
                            HStack {
                                Label("其他备份占用", systemImage: "ellipsis.rectangle.fill")
                                Spacer()
                                Text(formatSize(otherSize))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Label("云端总占用", systemImage: "icloud.fill")
                                .font(.body.bold())
                            Spacer()
                            Text(formatSize(cloudSizes.values.reduce(0, +)))
                                .bold()
                                .foregroundColor(.cyan)
                        }
                    }
                }
            }
            
            Section(header: Text("缓存与临时文件"), footer: Text("清理缓存不会影响您的卡片数据和同步账本。")) {
                HStack {
                    Label("诊断日志与临时文件", systemImage: "doc.text.fill")
                    Spacer()
                    if isCalculating {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text(formatSize(diagnosticsSize))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Label("系统缓存与临时文件", systemImage: "folder.badge.minus")
                    Spacer()
                    if isCalculating {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text(formatSize(cacheSize))
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(role: .destructive) {
                    guard !isCalculating && !isClearing && (diagnosticsSize > 0 || cacheSize > 0) else { return }
                    showClearAlert = true
                } label: {
                    HStack {
                        Spacer()
                        if isClearing {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text("一键清理缓存与日志")
                            .bold()
                            .foregroundColor((isCalculating || isClearing || (diagnosticsSize == 0 && cacheSize == 0)) ? .secondary : .red)
                        Spacer()
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .navigationTitle("存储管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateSizes()
            fetchCloudSizes()
        }
        .alert("确认清理缓存与日志", isPresented: $showClearAlert) {
            Button("清理", role: .destructive) {
                clearCachesAndLogs()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这将清理系统临时缓存以及诊断日志文件，释放磁盘空间。")
        }
        .overlay {
            if showSuccessToast {
                VStack {
                    Spacer()
                    Text("清理成功")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 24)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(20)
                        .padding(.bottom, 50)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func calculateSizes() {
        guard !isCalculating else { return }
        isCalculating = true
        
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            let docDir = paths[0]
            
            // 1. 卡片数据 cards.json
            let cardsURL = docDir.appendingPathComponent("CreditCardIOS/cards.json")
            let cardsAttr = try? fileManager.attributesOfItem(atPath: cardsURL.path)
            let cardsBytes = cardsAttr?[.size] as? Int64 ?? 0
            
            // 2. 同步账本 sync_ledger.json
            let ledgerURL = docDir.appendingPathComponent("CreditCardIOS/sync_ledger.json")
            let ledgerAttr = try? fileManager.attributesOfItem(atPath: ledgerURL.path)
            let ledgerBytes = ledgerAttr?[.size] as? Int64 ?? 0
            
            // 3. 诊断日志（Documents 根目录下的文件，排除子目录）
            var diagBytes: Int64 = 0
            if let files = try? fileManager.contentsOfDirectory(at: docDir, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsSubdirectoryDescendants]) {
                for file in files {
                    let resourceValues = try? file.resourceValues(forKeys: [.isDirectoryKey])
                    let isDirectory = resourceValues?.isDirectory ?? false
                    if !isDirectory {
                        let attr = try? fileManager.attributesOfItem(atPath: file.path)
                        diagBytes += attr?[.size] as? Int64 ?? 0
                    }
                }
            }
            
            // 4. 系统缓存 Library/Caches
            let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let cacheBytes = getFolderSize(at: cacheURL)
            
            // 5. 临时文件 NSTemporaryDirectory()
            let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            let tmpBytes = getFolderSize(at: tmpURL)
            
            await MainActor.run {
                self.cardsSize = cardsBytes
                self.ledgerSize = ledgerBytes
                self.diagnosticsSize = diagBytes
                self.cacheSize = cacheBytes + tmpBytes
                self.isCalculating = false
            }
        }
    }
    
    nonisolated private func getFolderSize(at url: URL) -> Int64 {
        var size: Int64 = 0
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: []) else { return 0 }
        for case let fileURL as URL in enumerator {
            autoreleasepool {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(keys)) else { return }
                if resourceValues.isDirectory == false {
                    size += Int64(resourceValues.fileSize ?? 0)
                }
            }
        }
        return size
    }
    
    private func clearCachesAndLogs() {
        isClearing = true
        
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            
            // 1. 清理 caches
            let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            if let cacheContents = try? fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil) {
                for item in cacheContents {
                    try? fileManager.removeItem(at: item)
                }
            }
            
            // 2. 清理 tmp
            let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            if let tmpContents = try? fileManager.contentsOfDirectory(at: tmpURL, includingPropertiesForKeys: nil) {
                for item in tmpContents {
                    try? fileManager.removeItem(at: item)
                }
            }
            
            // 3. 清理 Documents 根目录下文件（排除子目录，避免删除 CreditCardIOS 数据）
            let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            if let docContents = try? fileManager.contentsOfDirectory(at: docDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants]) {
                for item in docContents {
                    let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey])
                    let isDirectory = resourceValues?.isDirectory ?? false
                    if !isDirectory {
                        try? fileManager.removeItem(at: item)
                    }
                }
            }
            
            await MainActor.run {
                self.isClearing = false
                withAnimation {
                    self.showSuccessToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        self.showSuccessToast = false
                    }
                }
                calculateSizes()
            }
        }
    }
    
    private func fetchCloudSizes() {
        guard UserDefaults.standard.string(forKey: "webdav_url") != nil,
              KeychainManager.load(key: "webdav_username") != nil,
              KeychainManager.load(key: "webdav_password") != nil else {
            self.cloudError = "未配置云端同步"
            return
        }
        
        isFetchingCloud = true
        cloudError = nil
        
        Task {
            do {
                let files = try await withThrowingTaskGroup(of: [WebDAVBackupFile].self) { group in
                    group.addTask {
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[WebDAVBackupFile], Error>) in
                            WebDAVClient.shared.getBackupList { result in
                                continuation.resume(with: result)
                            }
                        }
                    }
                    
                    group.addTask {
                        try await Task.sleep(nanoseconds: 15_000_000_000)
                        throw URLError(.timedOut)
                    }
                    
                    guard let result = try await group.next() else {
                        throw URLError(.unknown)
                    }
                    group.cancelAll()
                    return result
                }
                
                var sizes: [String: Int64] = ["iOS": 0, "Mac": 0, "Web": 0, "Android": 0, "Other": 0]
                for file in files {
                    let name = file.filename.lowercased()
                    if name.contains("[ios]") {
                        sizes["iOS", default: 0] += file.size
                    } else if name.contains("[mac]") {
                        sizes["Mac", default: 0] += file.size
                    } else if name.contains("[web]") {
                        sizes["Web", default: 0] += file.size
                    } else if name.contains("[android]") {
                        sizes["Android", default: 0] += file.size
                    } else {
                        sizes["Other", default: 0] += file.size
                    }
                }
                
                await MainActor.run {
                    self.cloudSizes = sizes
                    self.isFetchingCloud = false
                }
            } catch {
                await MainActor.run {
                    self.cloudError = error.localizedDescription
                    self.isFetchingCloud = false
                }
            }
        }
    }
}
