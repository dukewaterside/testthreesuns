import SwiftUI
import Supabase
import PostgREST

struct NotificationsListView: View {
    @StateObject private var viewModel = NotificationViewModel()
    @EnvironmentObject var notificationService: NotificationService
    @State private var selectedFilter: NotificationFilter = .all
    
    enum NotificationFilter: String, CaseIterable {
        case all = "All"
        case cleaning = "Cleaning"
        case reservations = "Reservations"
        case checklists = "Checklists"
        case damage = "Damage"
    }
    
    var filteredNotifications: [AppNotification] {
        let notifications = viewModel.notifications
        
        switch selectedFilter {
        case .all:
            return notifications
        case .cleaning:
            return notifications.filter { $0.type.contains("cleaning") }
        case .reservations:
            return notifications.filter { $0.type.contains("reservation") || $0.type.contains("guest") }
        case .checklists:
            return notifications.filter { $0.type.contains("checklist") }
        case .damage:
            return notifications.filter { $0.type.contains("damage") || $0.type.contains("maintenance") }
        }
    }
    
    var groupedNotifications: [(String, String?, [AppNotification])] {
        let calendar = Calendar.current
        let now = Date()
        
        var grouped: [String: (String?, [AppNotification])] = [:]
        
        // Use EST timezone for date comparisons
        let estTimeZone = TimeZone(identifier: "America/New_York") ?? TimeZone.current
        var estCalendar = Calendar.current
        estCalendar.timeZone = estTimeZone
        
        for notification in filteredNotifications {
            // sentAt is stored in UTC, but we use EST calendar for comparisons
            // The calendar automatically handles the timezone conversion
            let date = notification.sentAt
            var sectionTitle = "This Week"
            var dateString: String? = nil
            
            if estCalendar.isDateInToday(date) {
                sectionTitle = "Today"
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMM d"
                formatter.timeZone = estTimeZone
                dateString = formatter.string(from: date)
            } else if estCalendar.isDateInYesterday(date) {
                sectionTitle = "Yesterday"
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMM d"
                formatter.timeZone = estTimeZone
                dateString = formatter.string(from: date)
            } else if let weekInterval = estCalendar.dateInterval(of: .weekOfYear, for: now),
                      weekInterval.contains(date) {
                sectionTitle = "This Week"
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMM d"
                formatter.timeZone = estTimeZone
                dateString = formatter.string(from: date)
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                formatter.timeZone = estTimeZone
                sectionTitle = formatter.string(from: date)
                formatter.dateFormat = "EEEE, MMM d"
                dateString = formatter.string(from: date)
            }
            
            if grouped[sectionTitle] == nil {
                grouped[sectionTitle] = (dateString, [])
            }
            grouped[sectionTitle]?.1.append(notification)
        }
        
        return grouped.map { (key, value) in
            (key, value.0, value.1.sorted { $0.sentAt > $1.sentAt })
        }.sorted { section1, section2 in
            guard let first1 = section1.2.first,
                  let first2 = section2.2.first else { return false }
            return first1.sentAt > first2.sentAt
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(NotificationFilter.allCases, id: \.self) { filter in
                            FilterButton(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                // Notifications list
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredNotifications.isEmpty {
                    EmptyStateView(message: "No notifications")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(groupedNotifications.enumerated()), id: \.offset) { index, group in
                            let (section, dateString, notifications) = group
                            Section {
                                ForEach(notifications) { notification in
                                    NotificationCard(notification: notification)
                                        .onTapGesture {
                                            markAsRead(notification)
                                            navigateToRelatedItem(notification)
                                        }
                                }
                            } header: {
                                HStack {
                                    Text(section)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if let dateString = dateString {
                                        Text(dateString)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.loadNotifications()
            }
            .task {
                await viewModel.loadNotifications()
                viewModel.subscribeToNotifications()
                // Update notification service with unread count
                notificationService.updateUnreadCount(viewModel.unreadCount)
            }
            .onChange(of: viewModel.unreadCount) { oldValue, newValue in
                notificationService.updateUnreadCount(newValue)
            }
            .onAppear {
                // Refresh notifications when view appears
                Task {
                    await viewModel.loadNotifications()
                    notificationService.updateUnreadCount(viewModel.unreadCount)
                }
            }
        }
    }
    
    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func markAsRead(_ notification: AppNotification) {
        guard !notification.isRead else { return }
        
        Task {
            do {
                let updateData: [String: AnyCodable] = ["is_read": AnyCodable(true)]
                
                try await SupabaseService.shared.supabase
                    .from("notifications")
                    .update(updateData)
                    .eq("id", value: notification.id)
                    .execute()
                
                await viewModel.loadNotifications()
            } catch {
                print("Error marking as read: \(error)")
            }
        }
    }
    
    private func navigateToRelatedItem(_ notification: AppNotification) {
        // Navigation logic based on notification type
        // This will be implemented based on the related_id and type
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.brandPrimary : Color(.systemGray5))
                .cornerRadius(20)
        }
    }
}

struct NotificationCard: View {
    let notification: AppNotification
    
    // Remove check-in and check-out text from notification body
    // Since these are already displayed in ReservationDetailsView bubbles
    private func removeCheckInCheckOut(from text: String) -> String {
        var cleaned = text
        // Remove "Check-in: ..." pattern
        cleaned = cleaned.replacingOccurrences(
            of: "\\s*Check-in:\\s*[^.]*(?:\\.|$)",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        // Remove "Check-out: ..." pattern
        cleaned = cleaned.replacingOccurrences(
            of: "\\s*Check-out:\\s*[^.]*(?:\\.|$)",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        // Clean up any double spaces or trailing periods
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\\.+$", with: "", options: .regularExpression)
        return cleaned
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Red star for important notifications, orange dot for unread
            if notification.isImportant {
                Image(systemName: "star.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 2)
            } else if !notification.isRead {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            } else {
                Spacer()
                    .frame(width: 8)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(notification.isRead ? .secondary : .primary)
                
                // For reservation/booking notifications, remove check-in/check-out from body
                // since it's already shown in the ReservationDetailsView bubbles
                let bodyText = (notification.type.contains("reservation") || 
                               notification.type.contains("booking") ||
                               notification.type.contains("guest")) 
                    ? removeCheckInCheckOut(from: notification.body) 
                    : notification.body
                
                Text(bodyText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Special formatting for reservation notifications with check-in/check-out
                if notification.type.contains("reservation") || 
                   notification.type.contains("booking") ||
                   notification.type.contains("guest") {
                    ReservationDetailsView(notificationBody: notification.body)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct ReservationDetailsView: View {
    let notificationBody: String
    
    var body: some View {
        // Parse check-in and check-out from notification body
        // Format: "New guest at [villa]. Check-in: Aug 22nd at 3:00 PM. Check-out: Aug 29th at 11:00 AM"
        if let checkInInfo = extractDateInfo(from: notificationBody, prefix: "Check-in"),
           let checkOutInfo = extractDateInfo(from: notificationBody, prefix: "Check-out") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check-in")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(8)
                    Text(checkInInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check-out")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(8)
                    Text(checkOutInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    private func extractDateInfo(from text: String, prefix: String) -> String? {
        // Look for patterns like "Check-in: Aug 22nd at 3:00 PM" or "Check-in Aug 22nd at 3:00 PM"
        // Also handle formats like "Check-in: Jan 18, 2026 at 12:00 AM"
        let patterns = [
            "\(prefix):\\s*([^.]*)",
            "\(prefix)\\s+([^.]*)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                let extracted = String(text[range]).trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                
                // Try to parse the date string (assumed to be in UTC) and convert to EST
                if let estFormatted = convertDateStringToEST(extracted) {
                    return estFormatted
                }
                
                // If conversion fails, return original
                return extracted
            }
        }
        return nil
    }
    
    // Convert a date string from UTC to EST format
    // Handles formats like "Jan 19, 2026 at 04:54 PM"
    private func convertDateStringToEST(_ dateString: String) -> String? {
        let estTimeZone = TimeZone(identifier: "America/New_York") ?? TimeZone.current
        
        // Try to parse the date string as UTC
        // The notification body contains dates in format like "Jan 19, 2026 at 04:54 PM"
        let utcFormatter = DateFormatter()
        utcFormatter.timeZone = TimeZone(identifier: "UTC")
        utcFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Try different date formats
        let dateFormats = [
            "MMM d, yyyy 'at' h:mm a",      // "Jan 19, 2026 at 4:54 PM"
            "MMM d, yyyy 'at' hh:mm a",     // "Jan 19, 2026 at 04:54 PM"
            "MMMM d, yyyy 'at' h:mm a",     // "January 19, 2026 at 4:54 PM"
        ]
        
        for format in dateFormats {
            utcFormatter.dateFormat = format
            if let date = utcFormatter.date(from: dateString) {
                // Format in EST with MM/DD/YYYY format
                let estFormatter = DateFormatter()
                estFormatter.timeZone = estTimeZone
                estFormatter.locale = Locale(identifier: "en_US_POSIX")
                estFormatter.dateFormat = "MM/dd/yyyy 'at' h:mm a"
                return estFormatter.string(from: date)
            }
        }
        
        return nil
    }
}
