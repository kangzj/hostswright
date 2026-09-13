import Foundation
import HostsCore
import Synchronization
/// Fires after any change to /etc/hosts, including the helper's own rewrites, so the resolver table never goes stale.
final class HostsFileWatch: Sendable {
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "\(helperMachServiceName).hosts-watch")
    private let source = Mutex<DispatchSourceFileSystemObject?>(nil)

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
        watch()
    }

    // Rewrites replace the inode, so the descriptor goes stale and the path must be reopened.
    private func watch() {
        let descriptor = open(HostsFile.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .extend, .delete, .rename, .attrib], queue: queue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            if !source.data.intersection([.delete, .rename]).isEmpty {
                source.cancel()
                watch()
            }
            onChange()
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source.withLock { $0 = source }
    }
}
