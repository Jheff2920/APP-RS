import Flutter
import UIKit

/// Copia un archivo abierto con “Abrir en Boleta Print” al tmp de la app.
enum IncomingFileBridge {
  static var channel: FlutterMethodChannel?
  static var pendingPath: String?
  static var lastIngestedUrl: String?
  static var lastIngestedAt: Date?
  static var ingestingUrl: String?
  private static let dedupeWindow: TimeInterval = 2

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
    // No enviar "opened" aquí: Dart aún no registra el handler en un cold start.
    // takePending() recoge pendingPath cuando la app ya está lista.
  }

  static func ingest(url: URL) {
    let key = url.absoluteString
    // AppDelegate + SceneDelegate disparan el mismo URL al abrir; no bloquear
    // reabrir el mismo archivo más tarde, ni un reintento si la copia falló.
    if ingestingUrl == key {
      return
    }
    if lastIngestedUrl == key,
       let at = lastIngestedAt,
       Date().timeIntervalSince(at) < dedupeWindow {
      return
    }
    ingestingUrl = key
    defer { ingestingUrl = nil }

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
      lastIngestedUrl = key
      lastIngestedAt = Date()
      send(path: dest.path)
    } catch {
      NSLog("IncomingFile copy failed: \(error.localizedDescription)")
    }
  }

  private static func send(path: String) {
    pendingPath = path
    channel?.invokeMethod("opened", arguments: path)
  }
}
