
import SwiftUI
import Stripe

@main
struct BudDropApp: App {
    @StateObject var authManager = AuthManager()
    
    init() {
        // Initialize Stripe SDK
        #if DEBUG
        StripeAPI.defaultPublishableKey = "your-test-publishable-key"
        #else
        StripeAPI.defaultPublishableKey = "your-live-publishable-key"
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(authManager)
        }
    }
}
