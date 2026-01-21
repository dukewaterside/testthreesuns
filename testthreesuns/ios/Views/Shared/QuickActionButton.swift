import SwiftUI

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let backgroundColor: Color
    
    init(icon: String, title: String, color: Color, backgroundColor: Color = Color(.systemGray6)) {
        self.icon = icon
        self.title = title
        self.color = color
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
    }
}
