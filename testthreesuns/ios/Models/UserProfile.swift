import Foundation

struct UserProfile: Identifiable, Codable {
    let id: UUID
    let firstName: String
    let lastName: String
    let role: UserRole?
    let isVerified: Bool
    let verifiedAt: Date?
    let requestedRole: UserRole?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    // Explicit CodingKeys to map database snake_case to Swift camelCase
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case role
        case isVerified = "is_verified"
        case verifiedAt = "verified_at"
        case requestedRole = "requested_role"
    }
    
    enum UserRole: String, Codable {
        case owner = "owner"
        case propertyManager = "property_manager"
        case cleaningStaff = "cleaning_staff"
        
        var displayName: String {
            switch self {
            case .owner: return "Owner"
            case .propertyManager: return "Property Manager"
            case .cleaningStaff: return "Cleaning Staff"
            }
        }
    }
}
