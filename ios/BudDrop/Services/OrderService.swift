
import Foundation
import Combine
import SwiftUI

class OrderService: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchOrders() {
        isLoading = true
        errorMessage = nil
        
        APIClient.shared.getOrders()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = self.handleError(error)
                }
            }, receiveValue: { response in
                self.orders = response.orders
            })
            .store(in: &cancellables)
    }
    
    func createOrder(productName: String, price: Double, businessId: String, completion: @escaping (Result<CreateOrderResponse, APIError>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        APIClient.shared.createOrder(productName: productName, price: price, businessId: businessId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = self.handleError(error)
                }
            }, receiveValue: { response in
                completion(.success(response))
                self.fetchOrders() // Refresh orders list
            })
            .store(in: &cancellables)
    }
    
    func updateOrderStatus(orderId: Int, status: OrderStatus, completion: @escaping (Result<Order, APIError>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        APIClient.shared.updateOrderStatus(orderId: orderId, status: status)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = self.handleError(error)
                }
            }, receiveValue: { response in
                // Update the local order in the orders array
                if let index = self.orders.firstIndex(where: { $0.id == orderId }) {
                    self.orders[index] = response.order
                }
                completion(.success(response.order))
            })
            .store(in: &cancellables)
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
