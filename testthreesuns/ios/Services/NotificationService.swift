import Foundation
import UserNotifications
import SwiftUI
import Combine
import Supabase
import PostgREST
import Auth

class NotificationService: NSObject, ObservableObject {
    @Published var unreadCount = 0
    
    static var shared: NotificationService?
    
    // This will be updated by NotificationViewModel when notifications are loaded
    // For push notifications later, this can be updated via realtime subscriptions
    func updateUnreadCount(_ count: Int) {
        DispatchQueue.main.async {
            self.unreadCount = count
        }
    }
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared = self
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func registerDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        
        Task {
            guard let session = try? await SupabaseService.shared.supabase.auth.session else { return }
            let userId = session.user.id
            
            let deviceData: [String: AnyCodable] = [
                "user_id": AnyCodable(userId.uuidString),
                "push_token": AnyCodable(tokenString),
                "platform": AnyCodable("ios"),
                "notifications_enabled": AnyCodable(true),
                "device_name": AnyCodable(UIDevice.current.name),
                "os_version": AnyCodable(UIDevice.current.systemVersion)
            ]
            
            do {
                try await SupabaseService.shared.supabase
                    .from("devices")
                    .upsert(deviceData, onConflict: "user_id")
                    .execute()
            } catch {
                print("Error registering device: \(error)")
            }
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        if let type = userInfo["type"] as? String,
           let relatedId = userInfo["related_id"] as? String {
            handleNotificationTap(type: type, relatedId: relatedId)
        }
        
        completionHandler()
    }
    
    private func handleNotificationTap(type: String, relatedId: String) {
        // Handle navigation based on notification type
    }
}
