import Cocoa
import FlutterMacOS

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

        self.level = .screenSaver
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

        let channel = FlutterMethodChannel(
            name: "window/animation",
            binaryMessenger: flutterViewController.engine.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {

            case "isMouseInsideWindow":
                let mouseLocation = NSEvent.mouseLocation
                let windowFrame = self.frame

                let inside =
                    mouseLocation.x >= windowFrame.minX &&
                    mouseLocation.x <= windowFrame.maxX &&
                    mouseLocation.y >= windowFrame.minY &&
                    mouseLocation.y <= windowFrame.maxY

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
                self.moveToNotch() {
                    result(true)
                }
            default:
                result(FlutterMethodNotImplemented)
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

        let animation = CASpringAnimation(keyPath: "frame")
        animation.fromValue = oldFrame
        animation.toValue = newFrame

        animation.mass = 1
        animation.stiffness = 150
        animation.damping = 15
        animation.initialVelocity = 0

        animation.duration = animation.settlingDuration

        self.animations = ["frame": animation]

        NSAnimationContext.runAnimationGroup { context in
            context.allowsImplicitAnimation = true
            context.duration = animation.duration
            self.animator().setFrame(newFrame, display: true)
        } completionHandler: {
            completion()
            self.animations = [:]
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

    func moveToNotch(completion: @escaping () -> Void) {
        guard let screen = self.screen else {
            completion()
            return
        }

        let screenFrame = screen.frame

        if isDynamicIsland {
            isDynamicIsland = false
            islandAnchorX = nil
            islandAnchorY = nil
            restoreWindow(completion: completion)
            oldFrame = nil
            return
        }

        isDynamicIsland = true

        if oldFrame == nil {
            let oldFrameSelf = self.frame
            let oldSize = NSSize(width: 160, height: 50)

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
            y: screenFrame.origin.y + screenFrame.height - 25,
            width: 160,
            height: 25
        )
        springAnimate(to: moveFrame, mass: 1, stiffness: 220, damping: 25) {
            self.contentView?.subviews
                .filter { $0 is NSVisualEffectView }
                .forEach { $0.removeFromSuperview() }
            let topEdge = screenFrame.origin.y + screenFrame.height  
            let expandFrame = NSRect(
                x: screenFrame.origin.x + (screenFrame.width - 420) / 2,
                y: topEdge - 45,
                width: 420,
                height: 45
            )

            self.springAnimate(to: expandFrame, mass: 1, stiffness: 150, damping: 25) {
                completion()
            }
        }
    }

    private func restoreWindow(completion: @escaping () -> Void) {
        guard let frame = oldFrame else { completion(); return }
        guard let screen = self.screen else { completion(); return }

        let screenFrame = screen.frame
        let collapseFrame = NSRect(
            x: screenFrame.origin.x + (screenFrame.width - 160) / 2,
            y: screenFrame.origin.y + screenFrame.height - 20,
            width: 160,
            height: 20
        )
        springAnimate(to: collapseFrame, mass: 1, stiffness: 120, damping: 12) {
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

// import Cocoa
// import FlutterMacOS
// import SwiftUI

// class MainFlutterWindow: NSWindow {

//     private var notchWindowController: NotchWindowController?

//     override func awakeFromNib() {
//         //super.awakeFromNib()
//         self.setFrame(.zero, display: false)
//     }
// }

// class NotchWindow: NSWindow {
//     override init(
//         contentRect: NSRect,
//         styleMask: NSWindow.StyleMask,
//         backing: NSWindow.BackingStoreType,
//         defer flag: Bool
//     ) {
//         super.init(
//             contentRect: contentRect,
//             styleMask: styleMask,
//             backing: backing,
//             defer: flag
//         )
//         isOpaque = false
//         alphaValue = 1
//         titleVisibility = .hidden
//         titlebarAppearsTransparent = true
//         backgroundColor = .clear
//         isMovable = false
//         collectionBehavior = [
//             .fullScreenAuxiliary,
//             .stationary,
//             .canJoinAllSpaces,
//             .ignoresCycle,
//         ]
//         level = .statusBar + 9
//         hasShadow = false
//     }

//     override var canBecomeKey: Bool { true }
//     override var canBecomeMain: Bool { true }
// }

// class NotchWindowController: NSWindowController {
//     weak var screen: NSScreen?
//     private let notchHeight: CGFloat = 200

//     init(screen: NSScreen) {
//         self.screen = screen

//         let topRect = CGRect(
//             x: screen.frame.origin.x,
//             y: screen.frame.origin.y + screen.frame.height - notchHeight,
//             width: screen.frame.width,
//             height: notchHeight
//         )

//         let window = NotchWindow(
//             contentRect: topRect,
//             styleMask: [.borderless, .fullSizeContentView],
//             backing: .buffered,
//             defer: false
//         )

//         super.init(window: window)

//         let notchSize = screen.notchSize
//         let deviceNotchRect = CGRect(
//             x: screen.frame.origin.x + (screen.frame.width - notchSize.width) / 2,
//             y: screen.frame.origin.y + screen.frame.height - notchSize.height,
//             width: notchSize.width > 0 ? notchSize.width : 150,
//             height: notchSize.height > 0 ? notchSize.height : 32
//         )

//         window.contentView = NSHostingView(
//             rootView: SimpleNotchView(
//                 deviceNotchRect: deviceNotchRect,
//                 screenRect: screen.frame
//             )
//         )

//         window.makeKeyAndOrderFront(nil)
//         window.orderFrontRegardless()
//     }

//     @available(*, unavailable)
//     required init?(coder: NSCoder) { fatalError() }

//     func destroy() {
//         window?.close()
//         window = nil
//     }
// }

// struct SimpleNotchView: View {
//     let deviceNotchRect: CGRect
//     let screenRect: CGRect

//     @State private var expanded = false

//     private let expandedSize = CGSize(width: 400, height: 160)

//     var currentWidth: CGFloat {
//         expanded ? expandedSize.width : deviceNotchRect.width
//     }

//     var currentHeight: CGFloat {
//         expanded ? expandedSize.height : deviceNotchRect.height
//     }

//     var body: some View {
//         ZStack(alignment: .top) {
//             RoundedRectangle(cornerRadius: expanded ? 26 : 10)
//                 .fill(Color.red)
//                 .frame(width: currentWidth, height: currentHeight)
//                 .shadow(
//                     color: .red.opacity(expanded ? 0.5 : 0),
//                     radius: 16
//                 )
//                 .animation(.interactiveSpring(
//                     duration: 0.5,
//                     extraBounce: 0.25,
//                     blendDuration: 0.125
//                 ), value: expanded)

//             if expanded {
//                 expandedContent
//                     .frame(width: expandedSize.width, height: expandedSize.height)
//                     .transition(.opacity.combined(with: .scale(scale: 0.95)))
//             }
//         }
//         .frame(maxWidth: .infinity, alignment: .center)
//         .frame(height: expanded ? expandedSize.height : deviceNotchRect.height, alignment: .top)
//         .contentShape(Rectangle())
//         .onHover { hovering in
//             withAnimation(.interactiveSpring(
//                 duration: 0.5,
//                 extraBounce: 0.25,
//                 blendDuration: 0.125
//             )) {
//                 expanded = hovering
//             }
//         }
//         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//     }

//     private var expandedContent: some View {
//         HStack(spacing: 16) {
//             VStack(alignment: .leading, spacing: 4) {
//                 Text("Now Playing")
//                     .font(.system(size: 11, weight: .semibold))
//                     .foregroundColor(.white.opacity(0.5))
//                 Text("Song Name")
//                     .font(.system(size: 14, weight: .medium))
//                     .foregroundColor(.white)
//                 Text("Artist")
//                     .font(.system(size: 12))
//                     .foregroundColor(.white.opacity(0.7))
//             }
//             Spacer()
//             HStack(spacing: 20) {
//                 Button(action: {}) {
//                     Image(systemName: "backward.fill")
//                         .foregroundColor(.white)
//                         .font(.system(size: 16))
//                 }
//                 .buttonStyle(.plain)
//                 Button(action: {}) {
//                     Image(systemName: "play.fill")
//                         .foregroundColor(.white)
//                         .font(.system(size: 22))
//                 }
//                 .buttonStyle(.plain)
//                 Button(action: {}) {
//                     Image(systemName: "forward.fill")
//                         .foregroundColor(.white)
//                         .font(.system(size: 16))
//                 }
//                 .buttonStyle(.plain)
//             }
//         }
//         .padding(.horizontal, 24)
//         .padding(.top, deviceNotchRect.height + 8)
//     }
// }