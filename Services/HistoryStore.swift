import Foundation
import Combine

/// Persists home-plant history as Codable JSON in the app's Documents directory.
@MainActor
final class HistoryStore: ObservableObject {

    @Published private(set) var plants: [PlantRecord] = []

    private let fileURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("history.json")
        load()
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

    /// Move the dragged pot so it sits where the target pot is (live drag-to-reorder).
    /// Does NOT write to disk — call `persistOrder()` once the drag ends, so we don't
    /// hit the filesystem on every hover-swap.
    func move(id: UUID, before target: UUID) {
        guard id != target,
              let from = plants.firstIndex(where: { $0.id == id }),
              let to = plants.firstIndex(where: { $0.id == target }) else { return }
        let moved = plants.remove(at: from)
        let insertAt = min(to, plants.count)
        plants.insert(moved, at: insertAt)
    }

    /// Swap two pots' positions (drag one onto another).
    func swap(_ a: UUID, _ b: UUID) {
        guard a != b,
              let i = plants.firstIndex(where: { $0.id == a }),
              let j = plants.firstIndex(where: { $0.id == b }) else { return }
        plants.swapAt(i, j)
    }

    /// Persist the current order after a drag finishes.
    func persistOrder() { save() }

    func plant(with id: UUID) -> PlantRecord? {
        plants.first { $0.id == id }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder.plantCare.decode([PlantRecord].self, from: data) {
            plants = decoded
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder.plantCare.encode(plants)
            try data.write(to: fileURL, options: [.atomic])
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
