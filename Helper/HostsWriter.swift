import Foundation
import HostsCore
import Synchronization

/// Serialises every rewrite of /etc/hosts and replaces the file atomically so a reader never sees a partial file.
final class HostsWriter: Sendable {
    struct WriteError: LocalizedError {
        let errorDescription: String?
    }

    private let lock = Mutex(())
    private let path = HostsFile.path

    func rewrite(_ transform: (HostsFile) -> HostsFile) throws {
        try lock.withLock { _ in
            let current = try String(contentsOfFile: path, encoding: .utf8)
            let updated = transform(HostsFile(parsing: current)).rendered()
            guard updated != current else { return }
            try replaceFile(with: updated)
        }
    }

    private func replaceFile(with contents: String) throws {
        let temporaryPath = path + ".hostswright.tmp"
        guard FileManager.default.createFile(
            atPath: temporaryPath,
            contents: Data(contents.utf8),
            attributes: [.posixPermissions: 0o644, .ownerAccountID: 0, .groupOwnerAccountID: 0]
        ) else {
            throw WriteError(errorDescription: "Could not create \(temporaryPath)")
        }
        guard rename(temporaryPath, path) == 0 else {
            let reason = String(cString: strerror(errno))
            unlink(temporaryPath)
            throw WriteError(errorDescription: "Could not replace \(path): \(reason)")
        }
    }
}
