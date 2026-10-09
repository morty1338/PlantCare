import UIKit

/// One turn in the clarification chat (in-memory for the session).
struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
    var image: UIImage?
}
