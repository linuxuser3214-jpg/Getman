import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // Retained for the window's lifetime so its method-channel handler stays alive.
  private let workspaceBookmarkPlugin = WorkspaceBookmarkPlugin()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    workspaceBookmarkPlugin.register(
      registrar: flutterViewController.registrar(forPlugin: "WorkspaceBookmarkPlugin"))

    super.awakeFromNib()
  }
}

/// Bridges macOS security-scoped bookmark creation/resolution so the sandboxed
/// app can keep writing to a user-chosen workspace folder across launches.
///
/// The folder grant from `NSOpenPanel` is alive only for the picking session;
/// to write on a later launch the app must persist a security-scoped bookmark
/// (entitlement `com.apple.security.files.bookmarks.app-scope`) and re-acquire
/// access from it. Channel: `getman/workspace_bookmark`.
class WorkspaceBookmarkPlugin {
  static let channelName = "getman/workspace_bookmark"

  // URLs we hold security-scoped access to for the process lifetime. Released
  // implicitly on exit; never grows beyond the single active workspace.
  private var accessing: [URL] = []

  func register(registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: WorkspaceBookmarkPlugin.channelName, binaryMessenger: registrar.messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickDirectory":
      pickDirectory(result: result)
    case "resolveBookmark":
      guard let args = call.arguments as? [String: Any],
        let bookmark = args["bookmark"] as? String
      else {
        result(nil)
        return
      }
      resolveBookmark(base64: bookmark, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pickDirectory(result: @escaping FlutterResult) {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.prompt = "Choose"
    panel.message = "Choose workspace folder"

    guard panel.runModal() == .OK, let url = panel.url else {
      result(nil)
      return
    }
    do {
      let data = try url.bookmarkData(
        options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
      result(["path": url.path, "bookmark": data.base64EncodedString()])
    } catch {
      // Bookmark creation failed, but the folder is still writable THIS session
      // via the open-panel grant — return the path with no bookmark.
      result(["path": url.path])
    }
  }

  private func resolveBookmark(base64: String, result: @escaping FlutterResult) {
    guard let data = Data(base64Encoded: base64) else {
      result(nil)
      return
    }
    var stale = false
    do {
      let url = try URL(
        resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil,
        bookmarkDataIsStale: &stale)
      guard url.startAccessingSecurityScopedResource() else {
        result(nil)
        return
      }
      accessing.append(url)
      var out: [String: Any] = ["path": url.path, "stale": stale]
      if stale,
        let fresh = try? url.bookmarkData(
          options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
      {
        // Recreate so the stored bookmark keeps resolving on future launches.
        out["bookmark"] = fresh.base64EncodedString()
      }
      result(out)
    } catch {
      result(nil)
    }
  }
}
