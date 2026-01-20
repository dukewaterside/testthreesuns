import Foundation

struct CleaningSchedule: Identifiable, Codable {
    let id: UUID
    let propertyId: UUID
    let reservationId: UUID?
    let cleanerId: UUID
    let scheduledStart: Date
    let scheduledEnd: Date?
    let status: CleaningStatus
    let completedAt: Date?
    
    // Explicit CodingKeys to map database snake_case to Swift camelCase
    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case reservationId = "reservation_id"
        case cleanerId = "cleaner_id"
        case scheduledStart = "scheduled_start"
        case scheduledEnd = "scheduled_end"
        case status
        case completedAt = "completed_at"
    }
    
    enum CleaningStatus: String, Codable {
        case scheduled = "scheduled"
        case inProgress = "in_progress"
        case completed = "completed"
        case overdue = "overdue"
        
        var displayName: String {
            switch self {
            case .scheduled: return "Scheduled"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .overdue: return "Overdue"
            }
        }
    }
}
