import SwiftUI
import UIKit

/// A saved, named photo of a place in the user's home where plants live.
struct Room: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var imageData: Data

    init(id: UUID = UUID(), name: String = "", imageData: Data) {
        self.id = id
        self.name = name
        self.imageData = imageData
    }

    // Backward-compatible: older saved rooms had no "name" field.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "" ?? ""
        imageData = try c.decode(Data.self, forKey: .imageData)
    }
}

/// Persists the user's room photos (for "home planning" placement advice).
@MainActor
final class RoomStore: ObservableObject {
    @Published private(set) var rooms: [Room] = []

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("rooms.json")
        load()
    }

    /// Decoded room images, ready to send to the API.
    var images: [UIImage] { rooms.compactMap { UIImage(data: $0.imageData) } }

    func add(_ image: UIImage, name: String) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        rooms.append(Room(name: name.trimmingCharacters(in: .whitespacesAndNewlines), imageData: data))
        save()
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = rooms.firstIndex(where: { $0.id == id }) else { return }
        rooms[i].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    func delete(_ id: UUID) {
        rooms.removeAll { $0.id == id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Room].self, from: data) else { return }
        rooms = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(rooms) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }
}
