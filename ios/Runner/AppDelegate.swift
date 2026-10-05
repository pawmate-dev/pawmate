import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var attachmentResult: FlutterResult?
  private var attachmentURL: URL?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PawmateAttachments")!
    FlutterMethodChannel(name: "dev.pawmate.app/attachments", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(FlutterMethodNotImplemented); return }
        guard call.method == "save" else { result(FlutterMethodNotImplemented); return }
        guard self.attachmentResult == nil else { result(FlutterError(code: "busy", message: "Another save is active", details: nil)); return }
        guard let arguments = call.arguments as? [String: Any], let name = arguments["name"] as? String,
          let bytes = arguments["bytes"] as? FlutterStandardTypedData, !name.isEmpty,
          !name.contains("/"), !name.contains("\\"), name != ".", name != "..",
          bytes.data.count <= 20 * 1024 * 1024,
          var presenter = (self.window ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }.first { $0.isKeyWindow })?.rootViewController else {
          result(FlutterError(code: "invalid", message: "Cannot export attachment", details: nil)); return
        }
        while let presented = presenter.presentedViewController { presenter = presented }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
          // An app-private temporary directory preserves the suggested filename.
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
          let url = directory.appendingPathComponent(name)
          try bytes.data.write(to: url, options: .atomic)
          self.attachmentURL = url
          self.attachmentResult = result
          let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
          picker.delegate = self
          presenter.present(picker, animated: true)
        } catch {
          try? FileManager.default.removeItem(at: directory)
          result(FlutterError(code: "save_failed", message: "Cannot export attachment", details: nil))
        }
      }
  }

  /// Releases private temporary bytes after success or cancellation, never user files.
  private func finishAttachmentExport(_ saved: Bool) {
    if let url = attachmentURL { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let result = attachmentResult
    attachmentURL = nil; attachmentResult = nil
    result?(saved)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finishAttachmentExport(!urls.isEmpty)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishAttachmentExport(false)
  }
}
