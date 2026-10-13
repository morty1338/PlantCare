import Foundation
import Combine
import UIKit

/// Persists home-plant history as Codable JSON in the app's Documents directory.
///
/// Reading, encoding (photos live inside the JSON) and writing all happen off the main
/// thread, so neither launch nor any edit ever blocks the UI.
@MainActor
final class HistoryStore: ObservableObject {

    @Published private(set) var plants: [PlantRecord] = []

    private let fileURL: URL
    /// Serial, so writes land in order and the file always ends up with the latest state.
    private let ioQueue = DispatchQueue(label: "PlantCare.HistoryStore.io", qos: .utility)

    /// Stored photos are kept at most this size; larger legacy ones are shrunk once.
    nonisolated static let photoMaxPixel: CGFloat = 900

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("history.json")
        let url = fileURL
        Task { [weak self] in
            let (loaded, shrunk) = await Task.detached(priority: .userInitiated) {
                HistoryStore.read(url)
            }.value
            guard let self else { return }
            // Anything added in the first instant (before loading finished) is kept.
            let fresh = self.plants.filter { new in !loaded.contains { $0.id == new.id } }
            self.plants = loaded + fresh
            if shrunk || !fresh.isEmpty { self.save() }
        }
    }

    // MARK: - Mutations

    /// Add a brand-new pot from an analysis result and return it.
    @discardableResult
    func addPlant(from analysis: PlantAnalysis, thumbnail: Data?, isCutout: Bool = false) -> PlantRecord {
        let entry = PlantEntry(from: analysis)
        let record = PlantRecord(
            speciesName: analysis.plantName ?? "Plant",
            thumbnailData: thumbnail,
            thumbnailIsCutout: isCutout,
            entries: [entry]
        )
        plants.append(record)
        save()
        return record
    }

    /// Append a new reading to an existing pot.
    func addEntry(_ analysis: PlantAnalysis, to plantID: UUID, thumbnail: Data?) {
        guard let index = plants.firstIndex(where: { $0.id == plantID }) else { return }
        plants[index].entries.append(PlantEntry(from: analysis))
        if let thumbnail { plants[index].thumbnailData = thumbnail }
        save()
    }

    /// Attach (or replace) the photo shown at the top of a plant's stem.
    func setPhoto(_ plantID: UUID, data: Data?) {
        guard let index = plants.firstIndex(where: { $0.id == plantID }) else { return }
        plants[index].thumbnailData = data
        plants[index].thumbnailIsCutout = false
        save()
    }

    func rename(_ plantID: UUID, to name: String) {
        guard let index = plants.firstIndex(where: { $0.id == plantID }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        plants[index].customName = trimmed.isEmpty ? nil : trimmed
        save()
    }

    func delete(_ plantID: UUID) {
        plants.removeAll { $0.id == plantID }
        save()
    }

    /// Live drag-to-reorder: put the pot at `newIndex`, the rest shift (like SoundMarks'
    /// `moveStack`). In memory only — call `persistOrder()` once the drag ends.
    func move(id: UUID, to newIndex: Int) {
        guard let index = plants.firstIndex(where: { $0.id == id }),
              plants.indices.contains(newIndex), index != newIndex else { return }
        let plant = plants.remove(at: index)
        plants.insert(plant, at: newIndex)
    }

    /// Persist the current order after a drag finishes.
    func persistOrder() { save() }

    func plant(with id: UUID) -> PlantRecord? {
        plants.first { $0.id == id }
    }

    // MARK: - Persistence

    /// Snapshot on the main thread (copy-on-write, free), encode and write in the background.
    private func save() {
        let snapshot = plants
        let url = fileURL
        ioQueue.async { HistoryStore.write(snapshot, to: url) }
    }

    /// Reads the saved garden. Photos stored before downscaling existed are shrunk once,
    /// which keeps the JSON — and therefore every launch and save — small.
    nonisolated private static func read(_ url: URL) -> (plants: [PlantRecord], shrunk: Bool) {
        guard let data = try? Data(contentsOf: url),
              var plants = try? JSONDecoder.plantCare.decode([PlantRecord].self, from: data) else {
            return ([], false)
        }
        var shrunk = false
        for index in plants.indices {
            guard let photo = plants[index].thumbnailData, photo.count > 350_000,
                  let image = UIImage(data: photo) else { continue }
            let small = ImagePrep.downscale(image, maxPixel: photoMaxPixel)
            let isCutout = plants[index].thumbnailIsCutout == true
            if let encoded = isCutout ? small.pngData() : small.jpegData(compressionQuality: 0.78) {
                plants[index].thumbnailData = encoded
                shrunk = true
            }
        }
        return (plants, shrunk)
    }

    nonisolated private static func write(_ plants: [PlantRecord], to url: URL) {
        do {
            let data = try JSONEncoder.plantCare.encode(plants)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Non-fatal: history simply won't persist this change.
            print("HistoryStore save failed: \(error)")
        }
    }
}

private extension JSONEncoder {
    static var plantCare: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var plantCare: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
