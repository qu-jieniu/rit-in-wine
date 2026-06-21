// RIT.app (MVP) — embeds the RIT GUI in a native macOS window via RoyalVNC.
// Connects to the FEX/Wine RIT running in the Lima VM (forwarded to localhost:5900).
// This is the MVP display layer; VM orchestration + raw-VZ come next.
import AppKit
import RoyalVNCKit

let VNC_HOST = ProcessInfo.processInfo.environment["RIT_VNC_HOST"] ?? "127.0.0.1"
let VNC_PORT = Int(ProcessInfo.processInfo.environment["RIT_VNC_PORT"] ?? "5900") ?? 5900
let VNC_PASS = ProcessInfo.processInfo.environment["RIT_VNC_PASS"] ?? "ritvnc"

final class RITController: NSObject, VNCConnectionDelegate {
    let window: NSWindow
    let imageView = NSImageView()
    var connection: VNCConnection?

    override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Rotman Interactive Trader — connecting…"
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        window.contentView = imageView
        super.init()
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func connect() {
        let settings = VNCConnection.Settings(
            isDebugLoggingEnabled: false,
            hostname: VNC_HOST,
            port: UInt16(VNC_PORT),
            isShared: true,
            isScalingEnabled: true,
            useDisplayLink: false,
            inputMode: .forwardKeyboardShortcutsIfNotInUseLocally,
            isClipboardRedirectionEnabled: false,
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
        switch state.status {
        case .connected:    window.title = "Rotman Interactive Trader"
        case .disconnected: window.title = "Rotman Interactive Trader — disconnected"
        default: break
        }
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

    func connection(_ c: VNCConnection, didCreateFramebuffer fb: VNCFramebuffer) { render(fb) }
    func connection(_ c: VNCConnection, didResizeFramebuffer fb: VNCFramebuffer) { render(fb) }
    func connection(_ c: VNCConnection, didUpdateFramebuffer fb: VNCFramebuffer,
                    x: UInt16, y: UInt16, width: UInt16, height: UInt16) { render(fb) }
    func connection(_ c: VNCConnection, didUpdateCursor cursor: VNCCursor) {}

    private func render(_ fb: VNCFramebuffer) {
        guard let cg = fb.cgImage else { return }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        DispatchQueue.main.async { self.imageView.image = img }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let controller = RITController()
controller.connect()
app.activate(ignoringOtherApps: true)
app.run()
