import Foundation

struct AppNotification: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let title: String
    let body: String
    let type: String
    let relatedId: UUID?
    let isRead: Bool
    let sentAt: Date
    let isImportant: Bool
    
    // Explicit CodingKeys to map database snake_case to Swift camelCase
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case body
        case type
        case relatedId = "related_id"
        case isRead = "is_read"
        case sentAt = "sent_at"
        case isImportant = "is_important"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        type = try container.decode(String.self, forKey: .type)
        relatedId = try container.decodeIfPresent(UUID.self, forKey: .relatedId)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        sentAt = try container.decode(Date.self, forKey: .sentAt)
        isImportant = try container.decodeIfPresent(Bool.self, forKey: .isImportant) ?? false
    }
    
    // EST timezone for all date formatting
    private var estTimeZone: TimeZone {
        TimeZone(identifier: "America/New_York") ?? TimeZone.current
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        // RelativeDateTimeFormatter uses the system timezone, which should be EST
        // The sentAt date is in UTC, but the relative time calculation works correctly
        return formatter.localizedString(for: sentAt, relativeTo: Date())
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = estTimeZone
        return formatter.string(from: sentAt)
    }
    
    var dateSection: String {
        var calendar = Calendar.current
        calendar.timeZone = estTimeZone
        let now = Date()
        
        // Use EST calendar for all comparisons - this automatically handles UTC to EST conversion
        if calendar.isDateInToday(sentAt) {
            return "Today"
        } else if calendar.isDateInYesterday(sentAt) {
            return "Yesterday"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(sentAt) == true {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            weekdayFormatter.timeZone = estTimeZone
            return weekdayFormatter.string(from: sentAt)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            formatter.timeZone = estTimeZone
            return formatter.string(from: sentAt)
        }
    }
    
    // Helper to get sentAt in EST for date comparisons
    // Dates in Swift are stored as UTC internally, but we need to compare them as if they were in EST
    // This returns the same Date object (since Date is timezone-agnostic), but we'll use EST calendar for comparisons
    var sentAtEST: Date {
        return sentAt
    }
    
    // Helper to convert a UTC date to EST for comparisons
    // This gets the date components in EST timezone
    private func getESTDateComponents(from date: Date) -> DateComponents {
        let estTimeZone = TimeZone(identifier: "America/New_York") ?? TimeZone.current
        var calendar = Calendar.current
        calendar.timeZone = estTimeZone
        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }
}
