import Foundation
import SwiftUI

struct Property: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let shortName: String?
    let address: String
    let airbnbListingId: String?
    let icalUrl: String
    let status: PropertyStatus
    
    var displayName: String {
        let trimmed = (shortName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? name : trimmed
    }
    
    // Explicit CodingKeys to map database snake_case to Swift camelCase
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case shortName = "short_name"
        case address
        case airbnbListingId = "airbnb_listing_id"
        case icalUrl = "ical_url"
        case status
    }
    
    enum PropertyStatus: String, Codable {
        case occupied = "occupied"
        case needsCleaning = "needs_cleaning"
        case vacantReady = "vacant_ready"
        case needsMaintenance = "needs_maintenance"
        
        var displayName: String {
            switch self {
            case .occupied: return "Occupied"
            case .needsCleaning: return "Needs Cleaning"
            case .vacantReady: return "Vacant - Ready"
            case .needsMaintenance: return "Needs Maintenance"
            }
        }
        
        var color: Color {
            switch self {
            case .occupied: return .blue
            case .needsCleaning: return .orange
            case .vacantReady: return .green
            case .needsMaintenance: return .red
            }
        }
    }
}
