
import Foundation
import Combine
import SwiftUI

class AuthManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var authError: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    private let tokenKey = "auth_token"
    private let userKey = "current_user"
    
    init() {
        loadSavedUser()
    }
    
    private func loadSavedUser() {
        if let token = UserDefaults.standard.string(forHTTPHeaderField: tokenKey) {
            APIClient.shared.setToken(token)
            
            if let userData = UserDefaults.standard.data(forKey: userKey),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                self.currentUser = user
                self.isAuthenticated = true
            } else {
                // Token exists but no user data, fetch user data
                fetchCurrentUser()
            }
        }
    }
    
    private func saveUserData(token: String, user: User) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        
        APIClient.shared.setToken(token)
        self.currentUser = user
        self.isAuthenticated = true
    }
    
    func login(username: String, password: String) {
        authError = nil
        
        APIClient.shared.login(username: username, password: password)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    self.authError = self.handleError(error)
                }
            }, receiveValue: { response in
                self.saveUserData(token: response.accessToken, user: response.user)
            })
            .store(in: &cancellables)
    }
    
    func register(username: String, password: String, role: UserRole, businessId: String? = nil, businessName: String? = nil) {
        authError = nil
        
        APIClient.shared.register(
            username: username,
            password: password,
            role: role,
            businessId: businessId,
            businessName: businessName
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { completion in
            if case .failure(let error) = completion {
                self.authError = self.handleError(error)
            }
        }, receiveValue: { response in
            self.saveUserData(token: response.accessToken, user: response.user)
        })
        .store(in: &cancellables)
    }
    
    func fetchCurrentUser() {
        APIClient.shared.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(_) = completion {
                    self.logout()
                }
            }, receiveValue: { user in
                self.currentUser = user
                self.isAuthenticated = true
                
                if let userData = try? JSONEncoder().encode(user) {
                    UserDefaults.standard.set(userData, forKey: self.userKey)
                }
            })
            .store(in: &cancellables)
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        
        APIClient.shared.clearToken()
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    private func handleError(_ error: APIError) -> String {
        switch error {
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Authentication failed"
        case .requestFailed(let err):
            return "Request failed: \(err.localizedDescription)"
        case .decodingFailed(_):
            return "Error processing server response"
        default:
            return "An unknown error occurred"
        }
    }
}

// Extension to properly set HTTPHeaderField in UserDefaults
extension UserDefaults {
    func string(forHTTPHeaderField field: String) -> String? {
        return string(forKey: field)
    }
}
