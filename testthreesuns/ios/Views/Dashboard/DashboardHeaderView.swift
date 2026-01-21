import SwiftUI

struct DashboardHeaderView: View {
    let firstName: String
    let role: UserProfile.UserRole
    @ObservedObject var viewModel: DashboardViewModel
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
    
    private var primaryStatTitle: String {
        "Active Reservations"
    }
    
    private var primaryStatValue: Int {
        viewModel.activeReservationsCount
    }
    
    private var secondaryStatTitle: String {
        "Pending Maintenance"
    }
    
    private var secondaryStatValue: Int {
        viewModel.pendingMaintenanceReportsCount
    }
    
    var body: some View {
        ZStack {
            // Background gradient - using Primary Color 1 from style guide
            LinearGradient(
                colors: [.brandPrimary, .brandPrimary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 16) {
                // Date and greeting row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                            .padding(.vertical, 4)
                        
                        Text("Welcome back,")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text(firstName)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(role.displayName)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Image("threesuns")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .accessibilityLabel("Three Suns")
                }
                
                // Stats row (owners only)
                if role == .owner {
                    HStack(spacing: 12) {
                        DashboardStatCard(
                            title: primaryStatTitle,
                            value: primaryStatValue
                        )
                        
                        DashboardStatCard(
                            title: secondaryStatTitle,
                            value: secondaryStatValue
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 0)
        .padding(.bottom, 24)
        .ignoresSafeArea(edges: .top)
    }
}

private struct DashboardStatCard: View {
    let title: String
    let value: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
            
            Text("\(value)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.18))
        .cornerRadius(18)
    }
}

