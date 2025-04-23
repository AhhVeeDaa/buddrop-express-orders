
import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let role: UserRole
    let businessId: String?
    let businessName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case role
        case businessId = "business_id"
        case businessName = "business_name"
    }
}

enum UserRole: String, Codable {
    case customer
    case business
}

struct AuthResponse: Codable {
    let accessToken: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user
    }
}
