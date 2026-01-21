import SwiftUI

extension Color {
    // Primary Colors
    static let brandPrimary = Color(hex: "3E6AFF") // Primary Color 1 (Blue)
    static let brandWhite = Color(hex: "FFFFFF") // Primary Color 2 (White)
    
    // Secondary Colors
    static let brandSecondary1 = Color(hex: "345252") // Secondary Color 1 (Dark Teal)
    static let brandSecondary2 = Color(hex: "F5F5F5") // Secondary Color 2 (Light Grey)
    
    // Status Colors
    static let checkInColor = Color(hex: "1ABF4A") // Check-in Green
    static let checkInBackground = Color(hex: "DCFCE7") // Check-in Background
    static let checkOutColor = Color(hex: "D04815") // Check-out Orange/Red
    static let checkOutBackground = Color(hex: "FFECD4") // Check-out Background
    static let scheduledColor = Color(hex: "4C0AA8") // Scheduled Purple
    static let scheduledBackground = Color(hex: "EAE2FF") // Scheduled Background
    static let repairedColor = Color(hex: "FF0000") // Repaired Red
    static let repairedBackground = Color(hex: "FFE2E2") // Repaired Background
    static let upcomingColor = Color(hex: "E903DA") // Upcoming Magenta
    static let upcomingBackground = Color(hex: "FFC3FB") // Upcoming Background
    static let inProgressColor = Color(hex: "3E6AFF") // In Progress Blue
    static let inProgressBackground = Color(hex: "E0E8FF") // In Progress Background
    static let completedColor = Color(hex: "1ABF4A") // Completed Green
    static let completedBackground = Color(hex: "DCFCE7") // Completed Background
    static let overdueColor = Color(hex: "D04815") // Overdue Orange/Red
    static let overdueBackground = Color(hex: "FFECD4") // Overdue Background
    
    // Text Colors
    static let textWhite = Color(hex: "FFFFFF")
    static let textLightGrey = Color(hex: "F6F3F3")
    static let textDarkGrey = Color(hex: "413E3E")
    static let textBlack = Color(hex: "000000")
    static let textGrey = Color(hex: "696767")
    
    // Icon Colors
    static let iconOrange = Color(hex: "FF6900") // Profile Orange
    
    // Legacy support - map to new colors
    static var brandTeal: Color { brandPrimary }
    static var brandBlue: Color { brandPrimary }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
