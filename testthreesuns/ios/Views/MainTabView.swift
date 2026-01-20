import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationService: NotificationService
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            notificationTab
                .tag(1)
            
            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
    }
    
    @ViewBuilder
    private var notificationTab: some View {
        Group {
            if notificationService.unreadCount > 0 {
                NotificationsListView()
                    .tabItem {
                        Label("Notification", systemImage: "bell.fill")
                    }
                    .badge(notificationService.unreadCount)
            } else {
                NotificationsListView()
                    .tabItem {
                        Label("Notification", systemImage: "bell.fill")
                    }
            }
        }
    }
}
