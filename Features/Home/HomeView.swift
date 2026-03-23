import SwiftUI

struct HomeView: View {
    var body: some View {
        List {
            Section("项目状态") {
                Text("iOS 原生工程骨架已初始化")
                Text("后续按 Docs 中的规范继续开发")
            }
        }
        .navigationTitle("信用卡")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
