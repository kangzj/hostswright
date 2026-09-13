import Foundation
import os

let log = Logger(subsystem: appBundleIdentifier, category: "Helper")

let dnsMode = DNSMode()
let hostsWatch = HostsFileWatch { Task { await dnsMode.hostsDidChange() } }
let listenerDelegate = HelperListener(service: HelperService(writer: HostsWriter(), dnsMode: dnsMode))
let listener = NSXPCListener(machServiceName: helperMachServiceName)
listener.delegate = listenerDelegate
listener.resume()

Task { await dnsMode.restoreAfterLaunch() }

log.notice("Listening on \(helperMachServiceName)")
dispatchMain()
