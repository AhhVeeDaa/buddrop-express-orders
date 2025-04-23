
import Foundation
import Combine

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(String)
    case unauthorized
    case unknown
}

class APIClient {
    static let shared = APIClient()
    
    private let session = URLSession.shared
    private let jsonDecoder = JSONDecoder()
    
    #if DEBUG
    private let baseURL = "http://localhost:5000/api"
    #else
    private let baseURL = "https://buddrop-app.herokuapp.com/api"
    #endif
    
    private var token: String?
    
    func setToken(_ token: String) {
        self.token = token
    }
    
    func clearToken() {
        self.token = nil
    }
    
    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil
    ) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Add auth token if available
        if let token = token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add request body if provided
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                return Fail(error: APIError.requestFailed(error))
                    .eraseToAnyPublisher()
            }
        }
        
        return session.dataTaskPublisher(for: request)
            .map { $0.data }
            .tryMap { data in
                // For debugging
                if let json = try? JSONSerialization.jsonObject(with: data),
                   let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
                   let jsonStr = String(data: jsonData, encoding: .utf8) {
                    print("Response: \(jsonStr)")
                }
                
                return data
            }
            .decode(type: T.self, decoder: jsonDecoder)
            .mapError { error in
                if let urlError = error as? URLError {
                    return APIError.requestFailed(urlError)
                } else if error is DecodingError {
                    return APIError.decodingFailed(error)
                } else {
                    return APIError.unknown
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Auth API
    
    func register(username: String, password: String, role: UserRole, businessId: String? = nil, businessName: String? = nil) -> AnyPublisher<AuthResponse, APIError> {
        var body: [String: Any] = [
            "username": username,
            "password": password,
            "role": role.rawValue
        ]
        
        if role == .business {
            guard let businessId = businessId, let businessName = businessName else {
                return Fail(error: APIError.invalidURL)
                    .eraseToAnyPublisher()
            }
            
            body["business_id"] = businessId
            body["business_name"] = businessName
        }
        
        return request(
            endpoint: "auth/register",
            method: "POST",
            body: body
        )
    }
    
    func login(username: String, password: String) -> AnyPublisher<AuthResponse, APIError> {
        return request(
            endpoint: "auth/login",
            method: "POST",
            body: [
                "username": username,
                "password": password
            ]
        )
    }
    
    func getCurrentUser() -> AnyPublisher<User, APIError> {
        return request(endpoint: "auth/me")
    }
    
    // MARK: - Orders API
    
    func createOrder(productName: String, price: Double, businessId: String) -> AnyPublisher<CreateOrderResponse, APIError> {
        return request(
            endpoint: "orders",
            method: "POST",
            body: [
                "product_name": productName,
                "price": price,
                "business_id": businessId
            ]
        )
    }
    
    func getOrders() -> AnyPublisher<OrdersResponse, APIError> {
        return request(endpoint: "orders")
    }
    
    func updateOrderStatus(orderId: Int, status: OrderStatus) -> AnyPublisher<UpdateOrderResponse, APIError> {
        return request(
            endpoint: "orders/\(orderId)/status",
            method: "PUT",
            body: [
                "status": status.rawValue
            ]
        )
    }
}

struct CreateOrderResponse: Codable {
    let message: String
    let order: Order
    let clientSecret: String
    
    enum CodingKeys: String, CodingKey {
        case message
        case order
        case clientSecret = "client_secret"
    }
}

struct OrdersResponse: Codable {
    let orders: [Order]
}

struct UpdateOrderResponse: Codable {
    let message: String
    let order: Order
}
