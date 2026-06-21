// RIT.app (v2) — native macOS wrapper. SKELETON: compiles/runs on a Mac only.
//
// Boots the RIT payload in a libkrun microVM (FEX inside runs the x86 Wine/RIT),
// then shows RIT's window via a native VNC view on the guest's :5900. The student
// double-clicks; the microVM is invisible.
//
// Build (on macOS 14+, Apple Silicon):
//   - link libkrun (brew/MacPorts: libkrun), sign with RIT.entitlements
//   - add a Swift VNC client package (e.g. RoyalVNC) for VNCView
//
// TODO markers = the Mac-side pieces to finish against the real target.

import SwiftUI
import Foundation

// MARK: - libkrun bridge (same C API as v2/libkrun/rit-vm.c)
// Declare the C symbols; link against libkrun.dylib. (Or use a module map.)
@_silgen_name("krun_create_ctx")      func krun_create_ctx() -> Int32
@_silgen_name("krun_set_vm_config")   func krun_set_vm_config(_ ctx: UInt32, _ vcpus: UInt8, _ ramMiB: UInt32) -> Int32
@_silgen_name("krun_set_root")        func krun_set_root(_ ctx: UInt32, _ path: UnsafePointer<CChar>) -> Int32
@_silgen_name("krun_set_root_disk")   func krun_set_root_disk(_ ctx: UInt32, _ path: UnsafePointer<CChar>) -> Int32
@_silgen_name("krun_set_port_map")    func krun_set_port_map(_ ctx: UInt32, _ map: UnsafePointer<UnsafePointer<CChar>?>) -> Int32
@_silgen_name("krun_set_exec")        func krun_set_exec(_ ctx: UInt32, _ exe: UnsafePointer<CChar>,
                                                          _ argv: UnsafePointer<UnsafePointer<CChar>?>?,
                                                          _ envp: UnsafePointer<UnsafePointer<CChar>?>?) -> Int32
@_silgen_name("krun_start_enter")     func krun_start_enter(_ ctx: UInt32) -> Int32

// MARK: - microVM controller
final class RitVM {
    /// Boot the payload in a microVM on a background thread (krun_start_enter blocks).
    /// rootPath: extracted payload rootfs dir (virtiofs). On Apple Silicon the
    /// payload is amd64 and FEX inside the guest runs it — FEX is part of the image.
    static func boot(rootPath: String) {
        Thread.detachNewThread {
            let ctx = krun_create_ctx()
            guard ctx >= 0 else { NSLog("krun_create_ctx failed"); return }
            let c = UInt32(ctx)
            _ = krun_set_vm_config(c, 4, 4096)
            _ = rootPath.withCString { krun_set_root(c, $0) }   // virtiofs (container rootfs)
            // Expose to the Mac's real localhost:
            //   9999 -> RIT REST API (students' Python/R hit http://localhost:9999 unchanged)
            //   5900 -> VNC (the GUI)
            withCStrings(["9999:9999", "5900:5900"]) { _ = krun_set_port_map(c, $0) }
            "/usr/local/bin/rit-desktop".withCString { exe in
                withCStrings(["HOME=/root", "PATH=/usr/local/bin:/usr/bin:/bin"]) { env in
                    _ = krun_set_exec(c, exe, nil, env)
                }
            }
            NSLog("booting RIT microVM…")
            _ = krun_start_enter(c)   // blocks until the VM exits
        }
    }
}

// helper: [String] -> NULL-terminated C array, valid for the closure
func withCStrings(_ strings: [String], _ body: (UnsafePointer<UnsafePointer<CChar>?>) -> Void) {
    var c = strings.map { strdup($0) } + [nil]
    c.withUnsafeBufferPointer { body($0.baseAddress!) }
    for p in c where p != nil { free(p) }
}

// MARK: - GUI display. Two options; pick one.
//
// The API (localhost:9999) is forwarded regardless — students' Python/R work
// unchanged. This is only about *showing RIT's window*.
//
// Option A (MVP, no dependency): macOS built-in Screen Sharing on :5900.
func openGUIWithScreenSharing() {
    // RIT's GUI opens in macOS's bundled VNC viewer — no VNC library needed.
    if let url = URL(string: "vnc://localhost:5900") { NSWorkspace.shared.open(url) }
}
//
// Option B (polish): embed the framebuffer in RIT.app's own window with a Swift
// VNC client (e.g. RoyalVNC). RoyalVNC is OPTIONAL — only for the embedded look.
struct VNCView: NSViewRepresentable {
    let host = "127.0.0.1"; let port = 5900
    func makeNSView(context: Context) -> NSView {
        // TODO (optional): RoyalVNC VNCConnection(host:port) -> framebuffer view.
        let v = NSView(); v.wantsLayer = true; v.layer?.backgroundColor = .black
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - App
@main struct RITApp: App {
    init() {
        // First run: extract the bundled payload rootfs to Application Support, then boot.
        let root = PayloadSetup.ensureRootfs()   // TODO: unpack Resources/payload.tar.zst once
        RitVM.boot(rootPath: root)
    }
    var body: some Scene {
        WindowGroup("Rotman Interactive Trader") {
            VNCView().frame(minWidth: 1280, minHeight: 800)
        }
    }
}

enum PayloadSetup {
    /// Expand Resources/payload (the v2 image rootfs) into a writable dir on first run.
    static func ensureRootfs() -> String {
        let dir = NSHomeDirectory() + "/Library/Application Support/RIT/rootfs"
        // TODO: if missing, extract Bundle.main Resources/payload.tar.zst -> dir
        return dir
    }
}
