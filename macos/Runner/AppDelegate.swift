import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationWillFinishLaunching(_ notification: Notification) {
    if let bundleId = Bundle.main.bundleIdentifier {
      let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
      let otherInstances = runningApps.filter { $0 != NSRunningApplication.current }
      if !otherInstances.isEmpty {
        let isStartup = CommandLine.arguments.contains("--startup") ||
          ProcessInfo.processInfo.environment["HAKKIN_STARTUP"] == "1"
        if !isStartup {
          for app in otherInstances {
            if app.isHidden {
              app.unhide()
            }
            if #available(macOS 14.0, *) {
              app.activate()
            } else {
              app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            }
          }
        }
        exit(0)
      }
    }
    super.applicationWillFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      sender.setActivationPolicy(.regular)
      for window in sender.windows {
        window.makeKeyAndOrderFront(self)
      }
      sender.activate(ignoringOtherApps: true)
    }
    return true
  }
}

