import Foundation

enum DNSCache {
    struct FlushError: LocalizedError {
        let errorDescription: String?
    }

    static func flush() throws {
        try run("/usr/bin/dscacheutil", ["-flushcache"])
        try run("/usr/bin/killall", ["-HUP", "mDNSResponder"])
    }

    private static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FlushError(errorDescription: "\(executable) exited with status \(process.terminationStatus)")
        }
    }
}
