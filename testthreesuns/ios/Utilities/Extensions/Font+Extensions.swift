import SwiftUI

extension Font {
    // Header Styles based on style guide
    static let h1: Font = .system(size: 34, weight: .regular, design: .default) // H1: 34pt Inter
    static let h2: Font = .system(size: 17, weight: .bold, design: .default) // H2: 17pt Inter Bold
    static let h3: Font = .system(size: 17, weight: .regular, design: .default) // H3: 17pt Inter
    static let h4: Font = .system(size: 13, weight: .semibold, design: .default) // H4: 13pt Inter Semi Bold
    static let h5: Font = .system(size: 13, weight: .medium, design: .default) // H5: 13pt Inter Medium
    
    // Note: SwiftUI uses system fonts. To use Inter specifically, you would need to:
    // 1. Add Inter font files to the project
    // 2. Register them in Info.plist
    // 3. Use .custom("Inter", size:) instead
    // For now, we use system fonts with matching weights and sizes
}
