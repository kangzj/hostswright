import Foundation

let appBundleIdentifier = "com.jasperkang.hostsmaster"
let helperMachServiceName = "com.jasperkang.hostsmaster.helper"
let helperProtocolVersion = 1

@objc protocol HostsMasterHelperProtocol {
    func version(reply: @escaping @Sendable (Int) -> Void)
    /// Replaces HostsMaster's section of /etc/hosts (nil removes it) and flushes the DNS cache.
    func applyManagedSection(_ section: String?, reply: @escaping @Sendable (String?) -> Void)
    /// Deletes exact matches of the given newline-separated lines outside the managed section.
    func removeUnmanagedLines(_ lines: String, reply: @escaping @Sendable (String?) -> Void)
    func flushDNSCache(reply: @escaping @Sendable (String?) -> Void)
}
