import SwiftUI

struct NotificationDetailView: View {
    @ObservedObject var viewModel: NotificationViewModel
    let notificationId: UUID

    private var notification: AppNotification? {
        viewModel.notifications.first(where: { $0.id == notificationId })
    }

    private var isReadBinding: Binding<Bool> {
        Binding(
            get: { notification?.isRead ?? false },
            set: { newValue in
                Task {
                    await viewModel.setReadStatus(notificationId: notificationId, isRead: newValue)
                }
            }
        )
    }

    private var typeLabel: String {
        guard let type = notification?.type, !type.isEmpty else { return "General" }
        return type.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    private var isReservationType: Bool {
        guard let type = notification?.type else { return false }
        let lowercased = type.lowercased()
        return lowercased.contains("reservation") || lowercased.contains("booking") || lowercased.contains("guest")
    }

    var body: some View {
        Group {
            if let notification {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(notification.title)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            // Label badge
                            if notification.isImportant {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    Text("URGENT")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.repairedBackground)
                                .cornerRadius(8)
                            } else if isReservationType {
                                HStack(spacing: 4) {
                                    Text("Reservation")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.checkInColor)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.checkInBackground)
                                .cornerRadius(8)
                            }

                            HStack(spacing: 8) {
                                Text(notification.formattedDate)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("•")
                                    .foregroundColor(.secondary)

                                Text(typeLabel)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text(notification.body)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            if isReservationType {
                                ReservationDetailsView(notificationBody: notification.body)
                                    .padding(.top, 4)
                            }
                        }

                        Divider()

                        Toggle("Mark as Read", isOn: isReadBinding)
                            .tint(.brandPrimary)
                    }
                    .padding()
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "bell")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Notification not found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Notification")
        .navigationBarTitleDisplayMode(.inline)
    }
}

