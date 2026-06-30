#if DEBUG
import Combine
import Foundation

struct ShaderLabPreset: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var style: ShaderEffectStyle
    var duration: Double
    var randomSeed: Double
    var parameters: ShaderLabParameterValues
    var createdAt: Date
}

@MainActor
final class ShaderLabPresetStore: ObservableObject {
    @Published private(set) var presets: [ShaderLabPreset] = []
    @Published private(set) var errorMessage: String?

    private let fileURL: URL
    private let fileManager: FileManager

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        load()
    }

    func presets(for style: ShaderEffectStyle) -> [ShaderLabPreset] {
        presets
            .filter { $0.style == style }
            .sorted { lhs, rhs in
                lhs.createdAt > rhs.createdAt
            }
    }

    func saveCurrent(
        style: ShaderEffectStyle,
        duration: Double,
        randomSeed: Double,
        parameters: ShaderLabParameterValues
    ) {
        let now = Date()
        let originalPresets = presets
        presets.append(
            ShaderLabPreset(
                id: UUID(),
                name: nextPresetName(for: style),
                style: style,
                duration: duration,
                randomSeed: randomSeed,
                parameters: parameters,
                createdAt: now
            )
        )
        rollbackOnPersistFailure {
            presets = originalPresets
        }
    }

    func delete(_ preset: ShaderLabPreset) {
        let originalPresets = presets
        presets.removeAll { $0.id == preset.id }
        rollbackOnPersistFailure {
            presets = originalPresets
        }
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            presets = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            presets = try JSONDecoder().decode([ShaderLabPreset].self, from: data)
            errorMessage = nil
        } catch {
            presets = []
            errorMessage = corruptPresetRecoveryMessage()
        }
    }

    private func persist() throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(presets)
        try data.write(to: fileURL, options: [.atomic])
        errorMessage = nil
    }

    private func rollbackOnPersistFailure(_ rollback: () -> Void) {
        do {
            try persist()
        } catch {
            rollback()
            errorMessage = "Failed to save presets"
        }
    }

    private func nextPresetName(for style: ShaderEffectStyle) -> String {
        let prefix = "\(style.displayName) "
        let nextIndex = presets
            .filter { $0.style == style }
            .compactMap { preset -> Int? in
                guard preset.name.hasPrefix(prefix) else {
                    return nil
                }

                return Int(preset.name.dropFirst(prefix.count))
            }
            .max()
            .map { $0 + 1 } ?? 1

        return "\(prefix)\(nextIndex)"
    }

    private func corruptPresetRecoveryMessage() -> String {
        let backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("ShaderLabPresets.corrupt.json")

        do {
            try? fileManager.removeItem(at: backupURL)
            try fileManager.moveItem(at: fileURL, to: backupURL)
            return "Corrupt preset file moved aside. Starting fresh."
        } catch {
            return "Failed to load presets; could not move corrupt file aside."
        }
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let directory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        return directory
            .appendingPathComponent("OverHyper", isDirectory: true)
            .appendingPathComponent("ShaderLabPresets.json")
    }
}
#endif
