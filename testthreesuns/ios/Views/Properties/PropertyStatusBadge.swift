import SwiftUI

struct StatusBadge: View {
    let status: Property.PropertyStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(status.color)
            .cornerRadius(8)
    }
}
