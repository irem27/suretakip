import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let databaseFileNames = [
    "suretakip_offline.sqlite",
    "suretakip_offline.sqlite-wal",
    "suretakip_offline.sqlite-shm",
    "suretakip_offline.sqlite-journal",
  ]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    hardenLocalDatabaseFiles()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    hardenLocalDatabaseFiles()
    super.applicationDidEnterBackground(application)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func hardenLocalDatabaseFiles() {
    guard let documentsURL = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else {
      return
    }

    try? FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
      ofItemAtPath: documentsURL.path
    )

    for fileName in databaseFileNames {
      var databaseURL = documentsURL.appendingPathComponent(fileName)
      guard FileManager.default.fileExists(atPath: databaseURL.path) else {
        continue
      }

      try? FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: databaseURL.path
      )
      var resourceValues = URLResourceValues()
      resourceValues.isExcludedFromBackup = true
      try? databaseURL.setResourceValues(resourceValues)
    }
  }
}
