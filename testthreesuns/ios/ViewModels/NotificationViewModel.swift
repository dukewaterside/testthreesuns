import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
class NotificationViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var isLoading = false
    
    private let supabase = SupabaseService.shared.supabase
    
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    func loadNotifications() async {
        isLoading = true
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            print("🔔 Loading notifications for user: \(userId)")
            
            let response: [AppNotification] = try await supabase
                .from("notifications")
                .select()
                .eq("user_id", value: userId)
                .order("sent_at", ascending: false)
                .limit(100)
                .execute()
                .value
            
            print("🔔 Loaded \(response.count) notifications")
            await MainActor.run {
                notifications = response
                print("🔔 Unread count: \(unreadCount)")
            }
        } catch {
            // Ignore cancellation errors (NSURLErrorDomain Code=-999)
            // These happen when the view disappears before the request completes
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                // Silently ignore - this is expected when view disappears
                await MainActor.run {
                    isLoading = false
                }
                return
            }
            
            print("❌ Error loading notifications: \(error)")
            if let error = error as? PostgrestError {
                print("❌ PostgrestError details: \(error)")
            }
        }
        await MainActor.run {
            isLoading = false
        }
    }
    
    func subscribeToNotifications() {
        // Realtime subscriptions will be configured based on Supabase Swift SDK version
        // For now, notifications will be loaded on view appear and refresh
        // TODO: Add Supabase Realtime subscription for push notifications
    }
}
