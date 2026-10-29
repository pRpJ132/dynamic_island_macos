import Cocoa
import FlutterMacOS
import MediaPlayer
import MusicKit

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame

        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        self.styleMask = [.titled, .fullSizeContentView]
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        self.isOpaque = false
        self.backgroundColor = .clear
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true

        self.collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]

        self.level = .statusBar
        self.hasShadow = false
        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()

        flutterViewController.backgroundColor = .clear

        let blurView = NSVisualEffectView(frame: self.contentView!.bounds)
        blurView.autoresizingMask = [.width, .height]
        blurView.blendingMode = .behindWindow
        blurView.material = .hudWindow
        blurView.state = .active
        blurView.wantsLayer = true
        self.contentView?.addSubview(blurView, positioned: .below, relativeTo: nil)

        RegisterGeneratedPlugins(registry: flutterViewController)

        let channelWindowAnimation = FlutterMethodChannel(
            name: "window/animation",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )

        channelWindowAnimation.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {

            case "isMouseInsideWindow":
                let inside = self.frame.contains(NSEvent.mouseLocation)
                result(inside)
            case "resize":
                guard
                    let args = call.arguments as? [String: Any],
                    let width = args["width"] as? CGFloat,
                    let height = args["height"] as? CGFloat,
                    let duration = args["duration"] as? Double,
                    let curve = args["curve"] as? String
                else {
                    result(FlutterError(code: "BAD_ARGS", message: "Invalid args", details: nil))
                    return
                }

                self.animateResize(
                    width: width,
                    height: height,
                    duration: duration,
                    curve: curve
                ) {
                    result(true)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let notchChannel = FlutterMethodChannel(
            name: "window/notch",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )

        notchChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {

            case "moveToNotch":
                guard
                    let args = call.arguments as? [String: Any],
                    let width = args["width"] as? CGFloat,
                    let height = args["height"] as? CGFloat,
                    let widthDynamicIsland = args["width_dynamic_island"] as? CGFloat,
                    let heightDynamicIsland = args["height_dynamic_island"] as? CGFloat
                else {
                    result(FlutterError(code: "BAD_ARGS", message: "Invalid args", details: nil))
                    return
                }
                self.moveToNotch(
                    width: width,
                    height: height,
                    widthDynamicIsland: widthDynamicIsland,
                    heightDynamicIsland: heightDynamicIsland
                ) {
                    result(true)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        let channelAppIcon = FlutterMethodChannel(
            name: "app.icon",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )

        channelAppIcon.setMethodCallHandler { call, result in
            if call.method == "getIcon" {
                guard let args = call.arguments as? [String: Any],
                    let path = args["path"] as? String else {
                result(nil)
                return
                }
                let icon = NSWorkspace.shared.icon(forFile: path)
                let tiffData = icon.tiffRepresentation
                result(tiffData)
            }
        }

        super.awakeFromNib()
    }

    private func springAnimate(
        to newFrame: NSRect,
        mass: CGFloat = 1,
        stiffness: CGFloat = 100,
        damping: CGFloat = 12,
        initialVelocity: CGFloat = 0,
        completion: @escaping () -> Void
    ) {
        let oldFrame = self.frame

        let spring = CASpringAnimation(keyPath: "frame")
        spring.fromValue = oldFrame
        spring.toValue = newFrame
        spring.mass = mass
        spring.stiffness = stiffness
        spring.damping = damping
        spring.initialVelocity = initialVelocity
        spring.duration = spring.settlingDuration

        self.animations = ["frame": spring]

        NSAnimationContext.runAnimationGroup { context in
            context.allowsImplicitAnimation = true
            context.duration = spring.settlingDuration
            self.animator().setFrame(newFrame, display: true)
        } completionHandler: {
            self.animations = [:]
            completion()
        }
    }

    private var isDynamicIsland = false
    private var islandAnchorY: CGFloat?
    private var islandAnchorX: CGFloat?

    private func animateResize(
        width: CGFloat,
        height: CGFloat,
        duration: Double,
        curve: String,
        completion: @escaping () -> Void
    ) {
        let oldFrame = self.frame
        let newSize = NSSize(width: width, height: height)

        if isDynamicIsland {
            if islandAnchorX == nil {
                islandAnchorX = oldFrame.midX
            }
            if islandAnchorY == nil {
                islandAnchorY = oldFrame.maxY
            }
        }

        let centerX = isDynamicIsland ? islandAnchorX! : oldFrame.midX

        let newY: CGFloat
        if isDynamicIsland {
            newY = islandAnchorY! - newSize.height
        } else {
            let centerY = oldFrame.midY
            newY = centerY - newSize.height / 2
        }

        var newFrame = NSRect(
            x: centerX - newSize.width / 2,
            y: newY,
            width: newSize.width,
            height: newSize.height
        )

        if let screenFrame = self.screen?.visibleFrame {
            newFrame.origin.x = max(screenFrame.minX,
                                    min(newFrame.origin.x,
                                        screenFrame.maxX - newSize.width))
        }

        self.springAnimate(to: newFrame, mass: 0.8, stiffness: 300 / duration, damping: 30 / duration) {
            completion()
        }
    }

    private func timingFunction(from curve: String) -> CAMediaTimingFunction {
        switch curve {
        case "easeIn":    return CAMediaTimingFunction(name: .easeIn)
        case "easeOut":   return CAMediaTimingFunction(name: .easeOut)
        case "easeInOut": return CAMediaTimingFunction(name: .easeInEaseOut)
        case "linear":    return CAMediaTimingFunction(name: .linear)
        default:          return CAMediaTimingFunction(name: .easeInEaseOut)
        }
    }

    private var oldFrame: NSRect?

    func moveToNotch(
        width: CGFloat,
        height: CGFloat,
        widthDynamicIsland: CGFloat,
        heightDynamicIsland: CGFloat,
        completion: @escaping () -> Void
    ) {
        guard let screen = self.screen else {
            completion()
            return
        }

        let screenFrame = screen.frame

        if isDynamicIsland {
            isDynamicIsland = false
            islandAnchorX = nil
            islandAnchorY = nil
            restoreWindow(width: width, height: height, completion: completion)
            oldFrame = nil
            return
        }

        isDynamicIsland = true

        if oldFrame == nil {
            let oldFrameSelf = self.frame
            let oldSize = NSSize(width: width, height: height)

            let centerX = oldFrameSelf.midX
            let centerY = oldFrameSelf.midY

            var newFrame = NSRect(
                x: centerX - oldSize.width / 2,
                y: centerY - oldSize.height / 2,
                width: oldSize.width,
                height: oldSize.height
            )

            if let visible = self.screen?.visibleFrame {
                newFrame.origin.x = max(visible.minX,
                                        min(newFrame.origin.x,
                                            visible.maxX - oldSize.width))
                newFrame.origin.y = max(visible.minY,
                                        min(newFrame.origin.y,
                                            visible.maxY - oldSize.height))
            }

            oldFrame = newFrame
        }

        self.styleMask = [.borderless, .fullSizeContentView]
        let moveFrame = NSRect(
            x: screenFrame.origin.x + (screenFrame.width - 160) / 2,
            y: screenFrame.origin.y + screenFrame.height - 20,
            width: 160,
            height: 20
        )
        springAnimate(to: moveFrame, mass: 1, stiffness: 220, damping: 25) {
            self.contentView?.subviews
                .filter { $0 is NSVisualEffectView }
                .forEach { $0.removeFromSuperview() }
            let topEdge = screenFrame.origin.y + screenFrame.height  
            let expandFrame = NSRect(
                x: screenFrame.origin.x + (screenFrame.width - widthDynamicIsland) / 2,
                y: topEdge - heightDynamicIsland,
                width: widthDynamicIsland,
                height: heightDynamicIsland
            )

            self.springAnimate(to: expandFrame, mass: 1, stiffness: 150, damping: 15) {
                completion()
            }
        }
    }

    private func restoreWindow(
        width: CGFloat,
        height: CGFloat,
        completion: @escaping () -> Void
    ) {
        guard var frame = oldFrame else { completion(); return }
        guard let screen = self.screen else { completion(); return }
        frame = NSRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: width,
            height: height
        )

        let screenFrame = screen.frame
        let collapseFrame = NSRect(
            x: screenFrame.origin.x + (screenFrame.width - 160) / 2,
            y: screenFrame.origin.y + screenFrame.height - 20,
            width: 160,
            height: 20
        )
        springAnimate(to: collapseFrame, mass: 1, stiffness: 150, damping: 25) {
            self.styleMask = [.titled, .fullSizeContentView]
            let blurView = NSVisualEffectView(frame: self.contentView!.bounds)
            blurView.autoresizingMask = [.width, .height]
            blurView.blendingMode = .behindWindow
            blurView.material = .fullScreenUI
            blurView.state = .active
            blurView.wantsLayer = true
            self.contentView?.addSubview(blurView, positioned: .below, relativeTo: nil)

            self.springAnimate(to: frame, mass: 1, stiffness: 220, damping: 25) {
                self.oldFrame = nil
                completion()
            }
        }
    }
}