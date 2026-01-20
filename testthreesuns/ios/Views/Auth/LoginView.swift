import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.brandPrimary, .brandPrimary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    if let logoImage = UIImage(named: "threesuns") {
                        Image(uiImage: logoImage)
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.white)
                            .frame(width: 280, height: 280)
                            .padding(.bottom, 40)
                    } else {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 120))
                            .foregroundColor(.white)
                            .padding(.bottom, 40)
                    }
                    
                    VStack(spacing: 16) {
                        TextField("Email", text: $email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .frame(height: 50)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        
                        SecureField("Password", text: $password)
                            .frame(height: 50)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 16)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        
                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            Task {
                                await authViewModel.signIn(email: email, password: password)
                            }
                        }) {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .tint(.brandPrimary)
                            } else {
                                Text("Sign In")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.brandPrimary)
                            }
                        }
                        .background(Color.brandWhite)
                        .cornerRadius(12)
                        .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)
                        
                        Divider()
                            .background(Color.white.opacity(0.5))
                            .padding(.vertical, 12)
                        
                        Button(action: {
                            showSignUp = true
                        }) {
                            Text("Create New Account")
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.brandPrimary)
                                .background(Color.brandWhite)
                                .cornerRadius(12)
                        }
                        .disabled(authViewModel.isLoading)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }
}
