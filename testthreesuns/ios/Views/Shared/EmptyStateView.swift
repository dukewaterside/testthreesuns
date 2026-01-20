import SwiftUI

struct EmptyStateView: View {
    let message: String
    let systemImage: String
    
    init(message: String, systemImage: String = "tray") {
        self.message = message
        self.systemImage = systemImage
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
