import SwiftUI

@main
struct CreditCardApp: App {
    init() {
        // 💡 注册全局应用内人机交互活动监听器，透明捕获鼠标移动与键盘操作，保障 5 分钟超时锁屏顺畅运转
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown]) { event in
            AutoLockManager.shared.resetActivity()
            return event
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
    }
}
