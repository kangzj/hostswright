import Foundation
import os

let log = Logger(subsystem: appBundleIdentifier, category: "Helper")

let listenerDelegate = HelperListener(service: HelperService(writer: HostsWriter()))
let listener = NSXPCListener(machServiceName: helperMachServiceName)
listener.delegate = listenerDelegate
listener.resume()

log.notice("Listening on \(helperMachServiceName)")
dispatchMain()
