import SwiftUI

struct QuickActionsSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NavigationLink(destination: CalendarView()) {
                    QuickActionButton(icon: "calendar", title: "View Calendar", color: .brandPrimary)
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: MaintenanceReportsListView()) {
                    ZStack(alignment: .topTrailing) {
                        QuickActionButton(icon: "wrench.and.screwdriver", title: "Maintenance Reports", color: .brandPrimary)
                        
                        // Badge for pending maintenance reports
                        if viewModel.pendingMaintenanceReportsCount > 0 {
                            Text("\(viewModel.pendingMaintenanceReportsCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: CleaningScheduleView()) {
                    QuickActionButton(icon: "list.bullet.rectangle", title: "Cleaning Schedules", color: .brandPrimary)
                }
                .buttonStyle(.plain)
                
                NavigationLink(destination: ActiveReservationsView()) {
                    QuickActionButton(icon: "calendar.badge.clock", title: "Reservations", color: .brandPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
