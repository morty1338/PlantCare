import SwiftUI
import UIKit

/// Drives the capture → loading → result flow.
@MainActor
final class AppViewModel: ObservableObject {

    /// The screen currently shown in the capture flow.
    enum Flow: Equatable {
        case idle                       // choosing mode + source
        case loading
        case result(PlantAnalysis)      // success (may be "not identified")
        case failure(String)            // network/API error, offers retry
    }

    @Published var mode: AppMode = .home
    @Published var flow: Flow = .idle
    @Published var capturedImage: UIImage?
    /// The pot created/updated in home mode for the current result, if any.
    @Published var savedPlantID: UUID?

    private let service = AnthropicService()
    /// Remembers the last request so "Try again" can replay it.
    private var lastRequest: Request?
    private var language: String = "English"

    private enum Request {
        case image(UIImage, rooms: [UIImage])
        case name(String)
    }

    // MARK: - Entry points

    func analyze(image: UIImage, history: HistoryStore, rooms: [UIImage] = [], language: String = "English") {
        capturedImage = image
        self.language = language
        lastRequest = .image(image, rooms: rooms)
        run(history: history)
    }

    func analyze(name: String, history: HistoryStore, language: String = "English") {
        self.language = language
        lastRequest = .name(name)
        run(history: history)
    }

    func retry(history: HistoryStore) {
        run(history: history)
    }

    /// Reset back to the mode/source chooser.
    func reset() {
        flow = .idle
        capturedImage = nil
        savedPlantID = nil
        lastRequest = nil
    }

    // MARK: - Execution

    private func run(history: HistoryStore) {
        guard let request = lastRequest else { return }
        flow = .loading
        savedPlantID = nil

        Task {
            do {
                let analysis: PlantAnalysis
                switch request {
                case .image(let image, let rooms):
                    analysis = try await service.analyze(image: image, rooms: rooms, language: language)
                case .name(let name):
                    analysis = try await service.analyze(plantName: name, language: language)
                }

                // Persist to history only in home mode, and only if identified.
                // Plants start as a vector illustration (no photo); the user can add
                // a photo later from the garden.
                if mode == .home && analysis.identified {
                    let record = history.addPlant(from: analysis, thumbnail: nil)
                    savedPlantID = record.id
                }

                flow = .result(analysis)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                flow = .failure(message)
            }
        }
    }
}
