import SwiftUI
import Supabase

@main
struct testthreesunsapp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var notificationService = NotificationService()
    
    init() {
        setupSupabase()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(notificationService)
                .onAppear {
                    notificationService.requestAuthorization()
                }
        }
    }
    
    private func setupSupabase() {
        let supabaseURL = URL(string: "https://tswktwukabazwnqevdul.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRzd2t0d3VrYWJhenducWV2ZHVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzMjYxNjEsImV4cCI6MjA4MzkwMjE2MX0.wtELjdN-B6aaqit4fAuid0fB4Ty-aRlqsObXvzDjQF4"
        
        SupabaseService.shared.configure(url: supabaseURL, key: supabaseKey)
    }
}
