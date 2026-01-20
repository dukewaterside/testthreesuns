import Foundation

struct Reservation: Identifiable, Codable, Hashable {
    let id: UUID
    let propertyId: UUID
    let airbnbReservationId: String?
    let guestName: String
    let guestCount: Int
    let checkIn: Date
    let checkOut: Date
    let status: ReservationStatus
    
    // Explicit CodingKeys to map database snake_case to Swift camelCase
    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case airbnbReservationId = "airbnb_reservation_id"
        case guestName = "guest_name"
        case guestCount = "guest_count"
        case checkIn = "check_in"
        case checkOut = "check_out"
        case status
    }
    
    enum ReservationStatus: String, Codable {
        case confirmed = "confirmed"
        case cancelled = "cancelled"
        case completed = "completed"
    }
    
    var isActive: Bool {
        let now = Date()
        return status == .confirmed && checkIn <= now && checkOut >= now
    }
}
