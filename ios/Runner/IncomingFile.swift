import Flutter
import UIKit

/// Copia un archivo abierto con “Abrir en Boleta Print” al tmp de la app.
enum IncomingFileBridge {
  static var channel: FlutterMethodChannel?
  static var pendingPath: String?

  static func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "boleta_print/incoming_file",
      binaryMessenger: messenger
    )
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      if call.method == "takePending" {
        let path = pendingPath
        pendingPath = nil
        result(path)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    if let pendingPath {
      channel.invokeMethod("opened", arguments: pendingPath)
      self.pendingPath = nil
    }
  }

  static func ingest(url: URL) {
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let ext = url.pathExtension.isEmpty ? "bin" : url.pathExtension
    let dest = FileManager.default.temporaryDirectory
      .appendingPathComponent("incoming-\(UUID().uuidString).\(ext)")
    do {
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: url, to: dest)
      send(path: dest.path)
    } catch {
      NSLog("IncomingFile copy failed: \(error.localizedDescription)")
    }
  }

  private static func send(path: String) {
    if let channel {
      channel.invokeMethod("opened", arguments: path)
    } else {
      pendingPath = path
    }
  }
}
