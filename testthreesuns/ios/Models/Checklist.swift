import Foundation

struct Checklist: Identifiable, Codable {
    let id: UUID
    let propertyId: UUID
    let reservationId: UUID?
    let managerId: UUID
    let items: [String: AnyCodable]
    let completedAt: Date?
    let propertyStatus: PropertyStatus?
    let checklistType: ChecklistType?
    
    // Explicit CodingKeys to map database snake_case to Swift camelCase
    enum CodingKeys: String, CodingKey {
        case id
        case propertyId = "property_id"
        case reservationId = "reservation_id"
        case managerId = "manager_id"
        case items
        case completedAt = "completed_at"
        case propertyStatus = "property_status"
        case checklistType = "checklist_type"
    }
    
    enum ChecklistType: String, Codable {
        case inspection = "inspection"
        case cleaning = "cleaning"
        case supplies = "supplies"
        case maintenance = "maintenance"
        
        var displayName: String {
            switch self {
            case .inspection: return "Inspection"
            case .cleaning: return "Cleaning"
            case .supplies: return "Supplies"
            case .maintenance: return "Maintenance"
            }
        }
    }
    
    enum PropertyStatus: String, Codable {
        case ready = "ready"
        case issuesFound = "issues_found"
        
        var displayName: String {
            switch self {
            case .ready: return "Ready for Use"
            case .issuesFound: return "Issues Found"
            }
        }
    }
    
    var isCompleted: Bool {
        completedAt != nil
    }
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Cannot encode AnyCodable"))
        }
    }
}
