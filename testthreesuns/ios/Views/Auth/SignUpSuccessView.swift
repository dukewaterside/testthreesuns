import SwiftUI
import UIKit

struct SignUpSuccessView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top gradient background
                VStack(spacing: 24) {
                    // Logo or icon
                    ZStack {
                        Circle()
                            .fill(Color.brandPrimary.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        if let logoImage = UIImage(named: "threesuns") {
                            Image(uiImage: logoImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                        } else {
                            Image(systemName: "envelope.badge.checkmark.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.brandPrimary)
                        }
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 12) {
                        Text("Check Your Email")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("We've sent you a verification link")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.bottom, 20)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .background(
                    LinearGradient(
                        colors: [Color.brandPrimary, Color.brandPrimary.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Content section
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 20) {
                            StepCard(
                                number: 1,
                                icon: "envelope.fill",
                                title: "Verify Your Email",
                                description: "Check your inbox and click the verification link in the email we just sent you."
                            )
                            
                            StepCard(
                                number: 2,
                                icon: "person.badge.key.fill",
                                title: "Await Admin Approval",
                                description: "An administrator will review your account and approve your access. This usually takes within 24 hours."
                            )
                            
                            StepCard(
                                number: 3,
                                icon: "bell.badge.fill",
                                title: "Get Notified",
                                description: "You'll receive an email notification once your account has been approved. Then you can sign in immediately!"
                            )
                        }
                        .padding(.top, 32)
                        .padding(.horizontal, 24)
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Back to Sign In")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.brandPrimary)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.brandPrimary)
                    }
                }
            }
        }
    }
}

struct StepCard: View {
    let number: Int
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number badge
            ZStack {
                Circle()
                    .fill(Color.brandPrimary)
                    .frame(width: 40, height: 40)
                
                Text("\(number)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.brandPrimary)
                    
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
