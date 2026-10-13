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
/// Photos are downscaled before storing; reading and writing happen off the main thread.
@MainActor
final class RoomStore: ObservableObject {
    @Published private(set) var rooms: [Room] = []

    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "PlantCare.RoomStore.io", qos: .utility)

    /// Rooms are sent to the API at ~680 px, so storing more is wasted space and time.
    nonisolated static let photoMaxPixel: CGFloat = 1100

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("rooms.json")
        let url = fileURL
        Task { [weak self] in
            let (loaded, shrunk) = await Task.detached(priority: .utility) { RoomStore.read(url) }.value
            guard let self else { return }
            let fresh = self.rooms.filter { new in !loaded.contains { $0.id == new.id } }
            self.rooms = loaded + fresh
            if shrunk || !fresh.isEmpty { self.save() }
        }
    }

    /// Room images, ready to send to the API (decoded lazily, off the main thread, by the service).
    var images: [UIImage] { rooms.compactMap { UIImage(data: $0.imageData) } }

    func add(_ image: UIImage, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            guard let data = await ImagePrep.storageData(for: image, maxPixel: Self.photoMaxPixel) else { return }
            rooms.append(Room(name: trimmed, imageData: data))
            save()
        }
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

    private func save() {
        let snapshot = rooms
        let url = fileURL
        ioQueue.async {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: url, options: [.atomic])
            }
        }
    }

    /// Reads saved rooms; full-size photos from older versions are shrunk once.
    nonisolated private static func read(_ url: URL) -> (rooms: [Room], shrunk: Bool) {
        guard let data = try? Data(contentsOf: url),
              var rooms = try? JSONDecoder().decode([Room].self, from: data) else { return ([], false) }
        var shrunk = false
        for index in rooms.indices where rooms[index].imageData.count > 450_000 {
            guard let image = UIImage(data: rooms[index].imageData),
                  let small = ImagePrep.downscale(image, maxPixel: photoMaxPixel)
                    .jpegData(compressionQuality: 0.78) else { continue }
            rooms[index].imageData = small
            shrunk = true
        }
        return (rooms, shrunk)
    }
}
