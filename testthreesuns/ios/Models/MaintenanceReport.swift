import Foundation
import SwiftUI

struct MaintenanceReport: Identifiable, Codable {
    let id: UUID
    let propertyId: UUID
    let reporterId: UUID
    let title: String
    let description: String
    let severity: Severity
    let status: ReportStatus
    let photos: [String]?
    let createdAt: Date?
    let reportType: ReportType?
    let location: String?
    let resolvedAt: Date?
    
    // Explicit CodingKeys to map database snake_case to Swift camelCase
    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case reporterId = "reporter_id"
        case title
        case description
        case severity
        case status
        case photos
        case createdAt = "created_at"
        case reportType = "report_type"
        case location
        case resolvedAt = "resolved_at"
    }
    
    enum Severity: String, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case urgent = "urgent"
        
        var displayName: String {
            rawValue.capitalized
        }
        
        var color: Color {
            switch self {
            case .low: return .checkInColor
            case .medium: return .checkOutColor
            case .high: return .repairedColor
            case .urgent: return .repairedColor
            }
        }
        
        /// Rank for sorting, with urgent shown first
        var priorityRank: Int {
            switch self {
            case .urgent: return 0
            case .high: return 1
            case .medium: return 2
            case .low: return 3
            }
        }
    }
    
    enum ReportStatus: String, Codable {
        case reported = "reported"
        case resolved = "resolved"
        
        var displayName: String {
            rawValue.capitalized
        }
    }
    
    enum ReportType: String, Codable {
        case maintenance = "maintenance"
        case damage = "damage"
        
        var displayName: String {
            rawValue.capitalized
        }
    }
}
