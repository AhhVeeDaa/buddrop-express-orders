
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var username = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var selectedRole: UserRole = .customer
    @State private var businessId = ""
    @State private var businessName = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Logo and App Name
                Image(systemName: "leaf.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.green)
                    .padding(.top, 50)
                
                Text("BudDrop")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 30)
                
                // Form
                VStack(spacing: 20) {
                    TextField(NSLocalizedString("Username", comment: "Username field"), text: $username)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .autocapitalization(.none)
                    
                    SecureField(NSLocalizedString("Password", comment: "Password field"), text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    if isRegistering {
                        Picker(NSLocalizedString("Account Type", comment: "Role selection"), selection: $selectedRole) {
                            Text(NSLocalizedString("Customer", comment: "Customer role")).tag(UserRole.customer)
                            Text(NSLocalizedString("Business", comment: "Business role")).tag(UserRole.business)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.vertical)
                        
                        if selectedRole == .business {
                            TextField(NSLocalizedString("Business ID", comment: "Business ID field"), text: $businessId)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .autocapitalization(.none)
                            
                            TextField(NSLocalizedString("Business Name", comment: "Business name field"), text: $businessName)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    
                    if let error = authManager.authError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.top, 5)
                    }
                    
                    // Action Button
                    Button(action: {
                        if isRegistering {
                            authManager.register(
                                username: username,
                                password: password,
                                role: selectedRole,
                                businessId: selectedRole == .business ? businessId : nil,
                                businessName: selectedRole == .business ? businessName : nil
                            )
                        } else {
                            authManager.login(username: username, password: password)
                        }
                    }) {
                        Text(isRegistering ? NSLocalizedString("Register", comment: "Register button") : NSLocalizedString("Login", comment: "Login button"))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    .disabled(username.isEmpty || password.isEmpty || 
                             (isRegistering && selectedRole == .business && (businessId.isEmpty || businessName.isEmpty)))
                    
                    // Switch between login/register
                    Button(action: {
                        isRegistering.toggle()
                        authManager.authError = nil
                    }) {
                        Text(isRegistering ? 
                             NSLocalizedString("Already have an account? Login", comment: "Switch to login") : 
                             NSLocalizedString("Don't have an account? Register", comment: "Switch to register"))
                            .foregroundColor(.green)
                            .padding(.top)
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthManager())
    }
}
