// RIT.app (MVP) — embeds the RIT GUI in a native macOS window via RoyalVNC, with
// full mouse/keyboard input (RoyalVNC's VNCCAFramebufferView handles rendering +
// input + scaling). Connects to the FEX/Wine RIT in the VM on localhost:5900.
import AppKit
import RoyalVNCKit

let VNC_HOST = ProcessInfo.processInfo.environment["RIT_VNC_HOST"] ?? "127.0.0.1"
let VNC_PORT = UInt16(ProcessInfo.processInfo.environment["RIT_VNC_PORT"] ?? "5900") ?? 5900
let VNC_PASS = ProcessInfo.processInfo.environment["RIT_VNC_PASS"] ?? "ritvnc"

final class RITController: NSObject, VNCConnectionDelegate {
    let window: NSWindow
    var connection: VNCConnection?
    var fbView: VNCCAFramebufferView?

    override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Rotman Interactive Trader — connecting…"
        window.contentView = NSView()   // placeholder until the framebuffer arrives
        super.init()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func connect() {
        let settings = VNCConnection.Settings(
            isDebugLoggingEnabled: false,
            hostname: VNC_HOST,
            port: VNC_PORT,
            isShared: true,
            isScalingEnabled: true,
            useDisplayLink: true,
            inputMode: .forwardKeyboardShortcutsIfNotInUseLocally,
            isClipboardRedirectionEnabled: true,
            colorDepth: .depth24Bit,
            frameEncodings: .default
        )
        let c = VNCConnection(settings: settings)
        c.delegate = self
        connection = c
        c.connect()
    }

    // MARK: VNCConnectionDelegate
    func connection(_ c: VNCConnection, stateDidChange state: VNCConnection.ConnectionState) {
        let title: String?
        switch state.status {
        case .connected:    title = "Rotman Interactive Trader"
        case .disconnected: title = "Rotman Interactive Trader — disconnected"
        default:            title = nil
        }
        if let title { DispatchQueue.main.async { self.window.title = title } }
    }

    func connection(_ c: VNCConnection, credentialFor authType: VNCAuthenticationType,
                    completion: @escaping (VNCCredential?) -> Void) {
        if authType.requiresUsername {
            completion(VNCUsernamePasswordCredential(username: "", password: VNC_PASS))
        } else if authType.requiresPassword {
            completion(VNCPasswordCredential(password: VNC_PASS))
        } else {
            completion(nil)
        }
    }

    func connection(_ c: VNCConnection, didCreateFramebuffer fb: VNCFramebuffer) {
        DispatchQueue.main.async {
            // The view takes over as the connection's delegate, handling framebuffer
            // updates + mouse/keyboard, and forwards state/credential back to us.
            let v = VNCCAFramebufferView(frame: self.window.contentView!.bounds,
                                         framebuffer: fb, connection: c, connectionDelegate: self)
            v.autoresizingMask = [.width, .height]
            self.window.contentView = v
            self.fbView = v
            self.window.makeFirstResponder(v)
        }
    }

    // After the view is created it becomes the delegate, so these won't fire on us;
    // they exist to satisfy the protocol before the framebuffer arrives.
    func connection(_ c: VNCConnection, didResizeFramebuffer fb: VNCFramebuffer) {}
    func connection(_ c: VNCConnection, didUpdateFramebuffer fb: VNCFramebuffer,
                    x: UInt16, y: UInt16, width: UInt16, height: UInt16) {}
    func connection(_ c: VNCConnection, didUpdateCursor cursor: VNCCursor) {}
}

// Owns the VM lifecycle: quitting RITApp (⌘Q or closing the window) stops the VM,
// so Wine/RIT/FEX/Xvfb all die with it — nothing lingers. (The raw-VZ version
// makes this in-process and crash-proof; for the Lima MVP we stop the VM.)
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ n: Notification) {
        guard ProcessInfo.processInfo.environment["RIT_OWN_VM"] != "0" else { return }
        let limactl = ProcessInfo.processInfo.environment["RIT_LIMACTL"]
            ?? NSHomeDirectory() + "/lima/bin/limactl"
        let vm = ProcessInfo.processInfo.environment["RIT_VM"] ?? "rit"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: limactl)
        p.arguments = ["stop", vm]
        try? p.run(); p.waitUntilExit()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
let controller = RITController()
controller.connect()
app.activate(ignoringOtherApps: true)
app.run()
