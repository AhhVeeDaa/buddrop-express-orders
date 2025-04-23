
import Foundation
import Combine
import Starscream

enum WebSocketEvent {
    case newOrder(Order)
    case orderStatusUpdated(Order)
    case paymentSucceeded(Order)
    case error(String)
}

class WebSocketService: ObservableObject {
    @Published var events = PassthroughSubject<WebSocketEvent, Never>()
    @Published var isConnected = false
    
    private var socket: WebSocket?
    private let decoder = JSONDecoder()
    
    #if DEBUG
    private let webSocketURL = "ws://localhost:5000/socket.io/?EIO=4&transport=websocket"
    #else
    private let webSocketURL = "wss://buddrop-app.herokuapp.com/socket.io/?EIO=4&transport=websocket"
    #endif
    
    func connect(token: String) {
        guard socket == nil else { return }
        
        var request = URLRequest(url: URL(string: webSocketURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()
    }
    
    func disconnect() {
        socket?.disconnect()
        socket = nil
        isConnected = false
    }
    
    func joinRoom(userId: Int, role: UserRole, businessId: String? = nil) {
        guard isConnected, let socket = socket else { return }
        
        // Create join event data
        var joinData: [String: Any] = [
            "role": role.rawValue,
            "user_id": userId
        ]
        
        if let businessId = businessId {
            joinData["business_id"] = businessId
        }
        
        // Send join event
        if let jsonData = try? JSONSerialization.data(withJSONObject: joinData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            socket.write(string: "42[\"join\",\(jsonString)]")
        }
    }
}

extension WebSocketService: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(_):
            isConnected = true
            print("WebSocket connected")
            
        case .disconnected(_, _):
            isConnected = false
            print("WebSocket disconnected")
            
        case .text(let string):
            handleSocketMessage(string)
            
        case .error(let error):
            isConnected = false
            if let error = error {
                events.send(.error("WebSocket error: \(error)"))
            } else {
                events.send(.error("WebSocket error"))
            }
            
        default:
            break
        }
    }
    
    private func handleSocketMessage(_ message: String) {
        // Socket.IO messages follow a specific format, e.g. "42["event_name",{...data...}]"
        // We need to parse this format to extract the event name and data
        
        guard message.hasPrefix("42[") else { return }
        
        // Extract JSON array part
        let startIndex = message.index(message.startIndex, offsetBy: 2)
        guard let jsonData = message[startIndex...].data(using: .utf8) else { return }
        
        do {
            guard let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [Any],
                  jsonArray.count >= 2,
                  let eventName = jsonArray[0] as? String else { return }
            
            // Extract the event data
            guard let eventData = jsonArray[1],
                  let eventJsonData = try? JSONSerialization.data(withJSONObject: eventData) else { return }
            
            // Handle different event types
            switch eventName {
            case "new_order":
                let payload = try decoder.decode([String: Order].self, from: eventJsonData)
                if let order = payload["order"] {
                    events.send(.newOrder(order))
                }
                
            case "order_status_updated":
                let payload = try decoder.decode([String: Order].self, from: eventJsonData)
                if let order = payload["order"] {
                    events.send(.orderStatusUpdated(order))
                }
                
            case "payment_succeeded":
                let payload = try decoder.decode([String: Order].self, from: eventJsonData)
                if let order = payload["order"] {
                    events.send(.paymentSucceeded(order))
                }
                
            case "error":
                let payload = try decoder.decode([String: String].self, from: eventJsonData)
                if let message = payload["message"] {
                    events.send(.error(message))
                }
                
            default:
                print("Unknown event: \(eventName)")
            }
            
        } catch {
            print("Error parsing socket message: \(error)")
        }
    }
}
