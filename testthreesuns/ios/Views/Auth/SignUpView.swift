import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedRole: UserProfile.UserRole = .propertyManager
    @State private var showingSuccess = false
    
    var body: some View {
        Form {
            Section("Account Information") {
                TextField("Email", text: $email)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                SecureField("Password", text: $password)
                
                SecureField("Confirm Password", text: $confirmPassword)
            }
            
            Section("Personal Information") {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
            }
            
            Section("Role") {
                Picker("Requested Role", selection: $selectedRole) {
                    ForEach([UserProfile.UserRole.owner, .propertyManager, .cleaningStaff], id: \.self) { role in
                        Text(role.displayName).tag(role)
                    }
                }
            }
            
            if let error = authViewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            Section {
                Button(action: {
                    Task {
                        await authViewModel.signUp(
                            email: email,
                            password: password,
                            firstName: firstName,
                            lastName: lastName,
                            requestedRole: selectedRole.rawValue
                        )
                        
                        // If signup successful (no error), show success page
                        if authViewModel.errorMessage == nil {
                            showingSuccess = true
                        }
                    }
                }) {
                    if authViewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Sign Up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(authViewModel.isLoading || !isFormValid)
            }
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingSuccess) {
            SignUpSuccessView()
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        !firstName.isEmpty &&
        !lastName.isEmpty
    }
}
