
import Foundation

struct Order: Codable, Identifiable {
    let id: Int
    let productName: String
    let price: Double
    let status: OrderStatus
    let businessId: String
    let customerId: Int
    let createdAt: String
    let updatedAt: String
    let paymentStatus: PaymentStatus
    let tipAmount: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case productName = "product_name"
        case price
        case status
        case businessId = "business_id"
        case customerId = "customer_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case paymentStatus = "payment_status"
        case tipAmount = "tip_amount"
    }
}

enum OrderStatus: String, Codable {
    case pending
    case confirmed
    case inDelivery = "in_delivery"
    case delivered
    
    var localizedDescription: String {
        switch self {
        case .pending:
            return NSLocalizedString("Pending", comment: "Order status pending")
        case .confirmed:
            return NSLocalizedString("Confirmed", comment: "Order status confirmed")
        case .inDelivery:
            return NSLocalizedString("In Delivery", comment: "Order status in delivery")
        case .delivered:
            return NSLocalizedString("Delivered", comment: "Order status delivered")
        }
    }
    
    var color: String {
        switch self {
        case .pending:
            return "yellow"
        case .confirmed:
            return "blue"
        case .inDelivery:
            return "orange"
        case .delivered:
            return "green"
        }
    }
}

enum PaymentStatus: String, Codable {
    case pending
    case succeeded
    case failed
    
    var localizedDescription: String {
        switch self {
        case .pending:
            return NSLocalizedString("Payment Pending", comment: "Payment status pending")
        case .succeeded:
            return NSLocalizedString("Payment Completed", comment: "Payment status succeeded")
        case .failed:
            return NSLocalizedString("Payment Failed", comment: "Payment status failed")
        }
    }
}
