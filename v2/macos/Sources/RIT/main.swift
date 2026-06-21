// RIT.app (v2) — native macOS wrapper. SKELETON: compiles/runs on a Mac only.
//
// Boots the RIT payload in a libkrun microVM (FEX inside runs the x86 Wine/RIT),
// shows RIT via an embedded VNC view, and forwards RIT's REST API to a host port
// for the students' Python/R. The microVM runs IN-PROCESS, so quitting the app
// tears everything down — no lingering Wine/VM processes (unlike v1).
//
// Build (macOS 14+, Apple Silicon): link libkrun, add RoyalVNC, sign with
// RIT.entitlements. TODO markers = the remaining Mac-side wiring.

import SwiftUI
import Foundation
import Network

// MARK: - libkrun bridge (same C API as v2/libkrun/rit-vm.c)
@_silgen_name("krun_create_ctx")    func krun_create_ctx() -> Int32
@_silgen_name("krun_set_vm_config") func krun_set_vm_config(_ c: UInt32, _ v: UInt8, _ r: UInt32) -> Int32
@_silgen_name("krun_set_root")      func krun_set_root(_ c: UInt32, _ p: UnsafePointer<CChar>) -> Int32
@_silgen_name("krun_set_port_map")  func krun_set_port_map(_ c: UInt32, _ m: UnsafePointer<UnsafePointer<CChar>?>) -> Int32
@_silgen_name("krun_set_exec")      func krun_set_exec(_ c: UInt32, _ e: UnsafePointer<CChar>,
                                                        _ a: UnsafePointer<UnsafePointer<CChar>?>?,
                                                        _ v: UnsafePointer<UnsafePointer<CChar>?>?) -> Int32
@_silgen_name("krun_start_enter")   func krun_start_enter(_ c: UInt32) -> Int32

// MARK: - host port selection (conflict-free, configurable)
enum HostPort {
    /// Prefer the course default (9999); if it's taken, fall back to a free port.
    static func pickAPI() -> UInt16 {
        let preferred = UInt16(UserDefaults.standard.integer(forKey: "apiPort"))
        let want = preferred != 0 ? preferred : 9999
        return isFree(want) ? want : freeEphemeral()
    }
    static func pickVNC() -> UInt16 { isFree(5900) ? 5900 : freeEphemeral() }

    static func isFree(_ port: UInt16) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0); defer { close(fd) }
        var a = sockaddr_in(); a.sin_family = sa_family_t(AF_INET)
        a.sin_port = port.bigEndian; a.sin_addr.s_addr = inet_addr("127.0.0.1")
        return withUnsafePointer(to: &a) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
    }
    static func freeEphemeral() -> UInt16 {
        let fd = socket(AF_INET, SOCK_STREAM, 0); defer { close(fd) }
        var a = sockaddr_in(); a.sin_family = sa_family_t(AF_INET); a.sin_addr.s_addr = inet_addr("127.0.0.1")
        _ = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            getsockname(fd, $0, &len) } }
        return UInt16(bigEndian: a.sin_port)
    }
}

// MARK: - microVM controller (boot + clean teardown)
final class VMController: ObservableObject {
    @Published var apiPort: UInt16 = 0
    @Published var vncPort: UInt16 = 0
    private var ctx: UInt32 = 0

    func boot() {
        apiPort = HostPort.pickAPI()
        vncPort = HostPort.pickVNC()
        let root = PayloadSetup.ensureRootfs()
        let api = apiPort, vnc = vncPort
        Thread.detachNewThread {
            let c = krun_create_ctx(); guard c >= 0 else { return }
            self.ctx = UInt32(c)
            _ = krun_set_vm_config(self.ctx, 4, 4096)
            _ = root.withCString { krun_set_root(self.ctx, $0) }
            // guest :9999 -> host apiPort (Python/R) ; guest :5900 -> host vncPort (GUI)
            withCStrings(["\(api):9999", "\(vnc):5900"]) { _ = krun_set_port_map(self.ctx, $0) }
            "/usr/local/bin/rit-desktop".withCString { exe in
                withCStrings(["HOME=/root", "PATH=/usr/local/bin:/usr/bin:/bin"]) { env in
                    _ = krun_set_exec(self.ctx, exe, nil, env) } }
            _ = krun_start_enter(self.ctx)   // runs the VM in-process; returns only when it stops
        }
    }

    /// The microVM is in-process — terminating the app process kills it (and Wine,
    /// RIT, FEX, Xvnc inside). We exit hard on quit so nothing can linger.
    func teardown() { exit(0) }
}

// MARK: - App
@main struct RITApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup("Rotman Interactive Trader") {
            ContentView(vm: delegate.vm).frame(minWidth: 1280, minHeight: 800)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let vm = VMController()
    func applicationDidFinishLaunching(_ n: Notification) { vm.boot() }
    func applicationWillTerminate(_ n: Notification) { vm.teardown() }            // no lingering
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

struct ContentView: View {
    @ObservedObject var vm: VMController
    var body: some View {
        VStack(spacing: 0) {
            // Embedded GUI -> closes with the app (no separate Screen Sharing window).
            VNCView(port: vm.vncPort)
            // Show the live API URL so students know where Python/R should point.
            Text(vm.apiPort == 9999
                 ? "API: http://localhost:9999/v1/  (default)"
                 : "API: http://localhost:\(vm.apiPort)/v1/  (9999 was busy — use this in Python/R)")
                .font(.caption).padding(4).frame(maxWidth: .infinity).background(.thinMaterial)
        }
    }
}

// Embedded VNC view — RoyalVNC connects to 127.0.0.1:vncPort and renders RIT.
struct VNCView: NSViewRepresentable {
    let port: UInt16
    func makeNSView(context: Context) -> NSView {
        // TODO: RoyalVNC VNCConnection(host:"127.0.0.1", port: Int(port)) -> framebuffer view
        let v = NSView(); v.wantsLayer = true; v.layer?.backgroundColor = .black; return v
    }
    func updateNSView(_ v: NSView, context: Context) {}
}

enum PayloadSetup {
    static func ensureRootfs() -> String {
        let dir = NSHomeDirectory() + "/Library/Application Support/RIT/rootfs"
        // TODO: first run -> extract Bundle Resources/payload.tar.zst (631 MB) -> dir
        return dir
    }
}

func withCStrings(_ s: [String], _ body: (UnsafePointer<UnsafePointer<CChar>?>) -> Void) {
    var c = s.map { strdup($0) } + [nil]
    c.withUnsafeBufferPointer { body($0.baseAddress!) }
    for p in c where p != nil { free(p) }
}
