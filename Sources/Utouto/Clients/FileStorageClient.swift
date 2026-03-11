import Foundation
import ComposableArchitecture

/// Single responsibility: file storage operations (e.g. copy to temp for drop handling).
/// Centralizes FileManager usage so views/reducers don't scatter path logic (SRP).
struct FileStorageClient {
    var copyToTemporaryDirectory: @Sendable (URL) throws -> URL
}

extension FileStorageClient: DependencyKey {
    static let liveValue = FileStorageClient(
        copyToTemporaryDirectory: { try FileStorageClientLive.copyToTemporaryDirectory(source: $0) }
    )
}

extension DependencyValues {
    var fileStorageClient: FileStorageClient {
        get { self[FileStorageClient.self] }
        set { self[FileStorageClient.self] = newValue }
    }
}

enum FileStorageClientLive {
    /// Shared implementation for both dependency and static call (e.g. from SwiftUI view in Transferable).
    static func copyToTemporaryDirectory(source: URL) throws -> URL {
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + ext)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: source, to: dest)
        return dest
    }
}

extension FileStorageClient {
    /// For use from views that don't have dependency injection (e.g. Transferable importing block).
    static func copyToTemporaryDirectory(source: URL) throws -> URL {
        try FileStorageClientLive.copyToTemporaryDirectory(source: source)
    }
}
