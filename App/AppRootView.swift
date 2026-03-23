import SwiftUI

struct AppRootView: View {
    var body: some View {
        NavigationSplitView {
            HomeSidebarView()
        } detail: {
            HomeDashboardView()
        }
    }
}

#Preview {
    AppRootView()
}
