
import SwiftUI
import Stripe

struct CustomerView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject var orderService = OrderService()
    @StateObject var webSocketService = WebSocketService()
    
    @State private var productName = ""
    @State private var price = ""
    @State private var businessId = ""
    @State private var isShowingPaymentSheet = false
    @State private var paymentSheet: PaymentSheet?
    @State private var paymentResult: PaymentSheetResult?
    
    var body: some View {
        NavigationView {
            VStack {
                // Order Form
                Form {
                    Section(header: Text("Place Order")) {
                        TextField("Product Name", text: $productName)
                        TextField("Price ($)", text: $price)
                            .keyboardType(.decimalPad)
                        TextField("Business ID", text: $businessId)
                    }
                    
                    Section {
                        Button(action: submitOrder) {
                            if orderService.isLoading {
                                ProgressView()
                            } else {
                                Text("Place Order")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .disabled(productName.isEmpty || price.isEmpty || businessId.isEmpty || orderService.isLoading)
                    }
                    
                    if let errorMessage = orderService.errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.footnote)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                // My Orders List
                List {
                    Section(header: Text("My Orders")) {
                        if orderService.orders.isEmpty && !orderService.isLoading {
                            Text("No orders yet")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(orderService.orders.sorted(by: { $0.createdAt > $1.createdAt })) { order in
                                OrderRowView(order: order)
                            }
                        }
                    }
                }
                .refreshable {
                    orderService.fetchOrders()
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("BudDrop")
            .navigationBarItems(trailing: 
                Button(action: {
                    authManager.logout()
                }) {
                    Text("Logout")
                }
            )
            .sheet(isPresented: $isShowingPaymentSheet) {
                if let paymentSheet = paymentSheet {
                    PaymentSheetUIView(paymentSheet: paymentSheet) { result in
                        paymentResult = result
                        isShowingPaymentSheet = false
                        handlePaymentResult()
                    }
                } else {
                    Text("Loading payment details...")
                        .padding()
                }
            }
            .onAppear {
                orderService.fetchOrders()
                setupWebSocket()
            }
            .onDisappear {
                webSocketService.disconnect()
            }
        }
    }
    
    private func submitOrder() {
        guard let priceValue = Double(price) else {
            orderService.errorMessage = "Invalid price"
            return
        }
        
        orderService.createOrder(productName: productName, price: priceValue, businessId: businessId) { result in
            switch result {
            case .success(let response):
                // Configure payment sheet
                let clientSecret = response.clientSecret
                var configuration = PaymentSheet.Configuration()
                configuration.merchantDisplayName = "BudDrop"
                
                PaymentSheet.Appearance().configure { appearance in
                    appearance.colors.primary = .systemGreen
                }
                
                StripeAPI.defaultPublishableKey = "your-publishable-key"
                
                paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
                isShowingPaymentSheet = true
                
                // Clear form
                productName = ""
                price = ""
                
            case .failure(let error):
                orderService.errorMessage = "Error creating order: \(error)"
            }
        }
    }
    
    private func handlePaymentResult() {
        guard let result = paymentResult else { return }
        
        switch result {
        case .completed:
            // Payment succeeded, order will be updated via webhook
            orderService.fetchOrders()
            
        case .canceled:
            orderService.errorMessage = "Payment canceled"
            
        case .failed(let error):
            orderService.errorMessage = "Payment failed: \(error.localizedDescription)"
        }
    }
    
    private func setupWebSocket() {
        guard let user = authManager.currentUser,
              let token = UserDefaults.standard.string(forKey: "auth_token") else {
            return
        }
        
        webSocketService.connect(token: token)
        
        // Listen for WebSocket events
        webSocketService.$isConnected
            .filter { $0 }
            .sink { _ in
                webSocketService.joinRoom(userId: user.id, role: user.role)
            }
            .cancel()
            
        webSocketService.events.sink { event in
            switch event {
            case .orderStatusUpdated(let order):
                // Update order status
                if let index = orderService.orders.firstIndex(where: { $0.id == order.id }) {
                    orderService.orders[index] = order
                }
                
            case .error(let message):
                orderService.errorMessage = message
                
            default:
                break
            }
        }
        .cancel()
    }
}

struct OrderRowView: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(order.productName)
                .font(.headline)
            
            HStack {
                Text("$\(String(format: "%.2f", order.price))")
                    .font(.subheadline)
                
                Spacer()
                
                Text(order.status.localizedDescription)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(for: order.status))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            HStack {
                Text("Business ID: \(order.businessId)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(formatDate(order.createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if order.paymentStatus != .succeeded {
                Text(order.paymentStatus.localizedDescription)
                    .font(.caption)
                    .foregroundColor(order.paymentStatus == .failed ? .red : .orange)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func statusColor(for status: OrderStatus) -> Color {
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

// Helper view to present the Stripe PaymentSheet
struct PaymentSheetUIView: UIViewControllerRepresentable {
    let paymentSheet: PaymentSheet
    let onCompletion: (PaymentSheetResult) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Present the payment sheet when view appears
        paymentSheet.present(from: uiViewController) { result in
            onCompletion(result)
        }
    }
}

struct CustomerView_Previews: PreviewProvider {
    static var previews: some View {
        CustomerView()
            .environmentObject(AuthManager())
    }
}
