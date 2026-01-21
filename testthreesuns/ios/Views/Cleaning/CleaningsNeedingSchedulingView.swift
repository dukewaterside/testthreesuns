import SwiftUI

struct CleaningsNeedingSchedulingView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var selectedProperty: Property?
    @State private var showingAll = false
    
    var reservationsNeedingCleaning: [Reservation] {
        let now = Date()
        
        // Get all upcoming confirmed reservations
        var upcomingReservations = viewModel.reservations
            .filter { $0.status == .confirmed && $0.checkIn >= now }
        
        // Filter by property if selected
        if let property = selectedProperty {
            upcomingReservations = upcomingReservations.filter { $0.propertyId == property.id }
        }
        
        // Get all scheduled cleaning reservation IDs from DB
        let scheduledCleaningReservationIds = Set(viewModel.cleaningSchedules
            .compactMap { $0.reservationId })
        
        // Filter out reservations that already have cleaning scheduled
        return upcomingReservations
            .filter { !scheduledCleaningReservationIds.contains($0.id) }
            .sorted { $0.checkIn < $1.checkIn }
    }
    
    var displayedReservations: [Reservation] {
        if showingAll {
            return reservationsNeedingCleaning
        } else {
            return Array(reservationsNeedingCleaning.prefix(2))
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Property Filter - Use LazyVGrid for better layout
                    if !viewModel.properties.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Filter by Property")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                Button(action: {
                                    selectedProperty = nil
                                }) {
                                    Text("All")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedProperty == nil ? Color.brandPrimary : Color(.systemGray5))
                                        .foregroundColor(selectedProperty == nil ? .white : .primary)
                                        .cornerRadius(10)
                                }
                                
                                ForEach(viewModel.properties) { property in
                                    Button(action: {
                                        selectedProperty = property
                                    }) {
                                        Text(property.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(selectedProperty?.id == property.id ? Color.brandPrimary : Color(.systemGray5))
                                            .foregroundColor(selectedProperty?.id == property.id ? .white : .primary)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // Reservations List
                    if reservationsNeedingCleaning.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            Text("All Cleanings Scheduled")
                                .font(.headline)
                            Text("No reservations need cleaning scheduling")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(displayedReservations) { reservation in
                            NavigationLink(destination: ScheduleCleaningView(preSelectedReservation: reservation)) {
                                ReservationCard(reservation: reservation, propertyName: viewModel.propertyName(for: reservation))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                        
                        if reservationsNeedingCleaning.count > 2 {
                            Button(action: {
                                showingAll.toggle()
                            }) {
                                HStack {
                                    Text(showingAll ? "Show Less" : "See All (\(reservationsNeedingCleaning.count))")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Image(systemName: showingAll ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                }
                                .foregroundColor(.brandPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.brandPrimary.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Schedule a Cleaning")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                NavigationLink(destination: ScheduleCleaningView()) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text("Schedule Cleaning")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandPrimary)
                    .cornerRadius(12)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .task {
                await viewModel.loadData()
            }
        }
    }
}
