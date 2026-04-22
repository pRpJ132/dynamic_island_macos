import Cocoa
import FlutterMacOS

extension NSScreen {
    static var buildin: NSScreen? {
        NSScreen.screens.first {
            guard let id = $0.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? CGDirectDisplayID else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }
    }

    var notchSize: CGSize {
        guard #available(macOS 12.0, *) else { return .zero }
        let insets = safeAreaInsets
        guard insets.top > 0 else { return .zero }
        return CGSize(width: 162, height: insets.top)
    }
}

@main
class AppDelegate: FlutterAppDelegate {
    // var notchWindowController: NotchWindowController?

    // override func applicationDidFinishLaunching(_ notification: Notification) {
    //     NSApp.setActivationPolicy(.accessory)

    //     NotificationCenter.default.addObserver(
    //         self,
    //         selector: #selector(rebuildWindows),
    //         name: NSApplication.didChangeScreenParametersNotification,
    //         object: nil
    //     )

    //     rebuildWindows()
    //     super.applicationDidFinishLaunching(notification)
    // }

    // @objc func rebuildWindows() {
    //     notchWindowController?.destroy()
    //     notchWindowController = nil

    //     let screen = NSScreen.buildin ?? NSScreen.main

    //     guard let screen else { return }
    //     notchWindowController = NotchWindowController(screen: screen)
    // }

    // override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    //     return true
    // }
}