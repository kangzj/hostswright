import Foundation
import HostsCore
import Observation
import os

/// Keeps an up-to-date parse of /etc/hosts and reports edits made by anyone, including the helper.
@MainActor
@Observable
final class HostsFileMonitor {
    private(set) var file: HostsFile
    var onChange: ((HostsFile) -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private let log = Logger(subsystem: appBundleIdentifier, category: "HostsFileMonitor")

    init() {
        file = Self.read()
        watch()
    }

    var customLines: [String] { file.customLines }

    func reload() {
        let latest = Self.read()
        guard latest != file else { return }
        file = latest
        onChange?(latest)
    }

    private static func read() -> HostsFile {
        HostsFile(parsing: (try? String(contentsOfFile: HostsFile.path, encoding: .utf8)) ?? "")
    }

    // Writers replace the file by rename, so the descriptor we watch goes stale and must be reopened.
    private func watch() {
        source?.cancel()
        let descriptor = open(HostsFile.path, O_EVTONLY)
        guard descriptor >= 0 else {
            log.error("Cannot watch \(HostsFile.path): \(String(cString: strerror(errno)))")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                if source.data.intersection([.delete, .rename]).isEmpty == false {
                    self.watch()
                }
                self.reload()
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }
}
