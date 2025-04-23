
import SwiftUI

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                // Show the appropriate view based on user role
                if let user = authManager.currentUser {
                    switch user.role {
                    case .customer:
                        CustomerView()
                            .environmentObject(authManager)
                    case .business:
                        BusinessView()
                            .environmentObject(authManager)
                    }
                } else {
                    // This shouldn't happen normally, but just in case
                    Text("Loading user information...")
                        .onAppear {
                            authManager.fetchCurrentUser()
                        }
                }
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(AuthManager())
    }
}
