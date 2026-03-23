import SwiftUI

struct HomeSidebarView: View {
    var body: some View {
        List {
            Text("卡片列表")
            Text("导入导出")
            Text("设置")
        }
        .navigationTitle("信用卡")
    }
}
