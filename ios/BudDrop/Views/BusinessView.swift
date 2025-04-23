
import SwiftUI

struct BusinessView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject var orderService = OrderService()
    @StateObject var webSocketService = WebSocketService()
    
    @State private var selectedOrderStatus: OrderStatus? = nil
    @State private var isFilteringActive = false
    
    var filteredOrders: [Order] {
        if let status = selectedOrderStatus, isFilteringActive {
            return orderService.orders.filter { $0.status == status }
        } else {
            return orderService.orders
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Status filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterChip(title: "All", isSelected: !isFilteringActive) {
                            isFilteringActive = false
                        }
                        
                        FilterChip(title: OrderStatus.pending.localizedDescription, isSelected: selectedOrderStatus == .pending && isFilteringActive) {
                            selectedOrderStatus = .pending
                            isFilteringActive = true
                        }
                        
                        FilterChip(title: OrderStatus.confirmed.localizedDescription, isSelected: selectedOrderStatus == .confirmed && isFilteringActive) {
                            selectedOrderStatus = .confirmed
                            isFilteringActive = true
                        }
                        
                        FilterChip(title: OrderStatus.inDelivery.localizedDescription, isSelected: selectedOrderStatus == .inDelivery && isFilteringActive) {
                            selectedOrderStatus = .inDelivery
                            isFilteringActive = true
                        }
                        
                        FilterChip(title: OrderStatus.delivered.localizedDescription, isSelected: selectedOrderStatus == .delivered && isFilteringActive) {
                            selectedOrderStatus = .delivered
                            isFilteringActive = true
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                if orderService.isLoading {
                    ProgressView()
                        .padding()
                } else if orderService.orders.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "list.clipboard")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No orders yet")
                            .font(.headline)
                        Text("Orders will appear here when customers place them")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredOrders.sorted(by: { $0.createdAt > $1.createdAt })) { order in
                            BusinessOrderRow(order: order) { order, newStatus in
                                updateOrderStatus(order: order, newStatus: newStatus)
                            }
                        }
                    }
                    .refreshable {
                        orderService.fetchOrders()
                    }
                    .listStyle(InsetGroupedListStyle())
                }
                
                if let errorMessage = orderService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding()
                }
            }
            .navigationTitle("Business Dashboard")
            .navigationBarItems(trailing: 
                Button(action: {
                    authManager.logout()
                }) {
                    Text("Logout")
                }
            )
            .onAppear {
                orderService.fetchOrders()
                setupWebSocket()
            }
            .onDisappear {
                webSocketService.disconnect()
            }
        }
    }
    
    private func updateOrderStatus(order: Order, newStatus: OrderStatus) {
        orderService.updateOrderStatus(orderId: order.id, status: newStatus) { _ in 
            // Status updated through OrderService
        }
    }
    
    private func setupWebSocket() {
        guard let user = authManager.currentUser,
              let token = UserDefaults.standard.string(forKey: "auth_token"),
              let businessId = user.businessId else {
            return
        }
        
        webSocketService.connect(token: token)
        
        // Listen for WebSocket events
        webSocketService.$isConnected
            .filter { $0 }
            .sink { _ in
                webSocketService.joinRoom(userId: user.id, role: user.role, businessId: businessId)
            }
            .cancel()
            
        webSocketService.events.sink { event in
            switch event {
            case .newOrder(_), .paymentSucceeded(_):
                // Refresh orders when a new order is received or payment succeeds
                orderService.fetchOrders()
                
            case .error(let message):
                orderService.errorMessage = message
                
            default:
                break
            }
        }
        .cancel()
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.footnote)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.green : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct BusinessOrderRow: View {
    let order: Order
    let onStatusChange: (Order, OrderStatus) -> Void
    
    @State private var isShowingActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text(order.productName)
                        .font(.headline)
                    
                    Text("$\(String(format: "%.2f", order.price))")
                        .font(.subheadline)
                }
                
                Spacer()
                
                StatusBadge(status: order.status)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order #\(order.id)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(formatDate(order.createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {
                    isShowingActions = true
                }) {
                    Text("Update Status")
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .actionSheet(isPresented: $isShowingActions) {
                    ActionSheet(
                        title: Text("Update Order Status"),
                        message: Text("Select a new status for this order"),
                        buttons: [
                            .default(Text("Pending")) {
                                onStatusChange(order, .pending)
                            },
                            .default(Text("Confirmed")) {
                                onStatusChange(order, .confirmed)
                            },
                            .default(Text("In Delivery")) {
                                onStatusChange(order, .inDelivery)
                            },
                            .default(Text("Delivered")) {
                                onStatusChange(order, .delivered)
                            },
                            .cancel()
                        ]
                    )
                }
                .disabled(order.paymentStatus != .succeeded)
            }
            
            if order.paymentStatus != .succeeded {
                HStack {
                    Image(systemName: order.paymentStatus == .pending ? "exclamationmark.circle" : "xmark.circle")
                        .foregroundColor(order.paymentStatus == .pending ? .orange : .red)
                    
                    Text(order.paymentStatus == .pending ? "Payment pending" : "Payment failed")
                        .font(.caption)
                        .foregroundColor(order.paymentStatus == .pending ? .orange : .red)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: OrderStatus
    
    var body: some View {
        Text(status.localizedDescription)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .pending:
            return .orange
        case .confirmed:
            return .blue
        case .inDelivery:
            return .purple
        case .delivered:
            return .green
        }
    }
}

struct BusinessView_Previews: PreviewProvider {
    static var previews: some View {
        BusinessView()
            .environmentObject(AuthManager())
    }
}
