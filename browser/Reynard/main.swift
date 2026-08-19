//
//  main.swift
//  Reynard
//
//  Created by Minh Ton on 1/2/26.
//

import Foundation
import GeckoView
import UIKit
import Darwin

private func configureRootHideRuntimePolicy() {
    guard isRootHideInjectionActive() else {
        return
    }

    // RootHide injects into every NSExtension-based Gecko helper. Keeping
    // speculative or idle content processes alive in that environment causes
    // duplicate injected helpers and unnecessary wakeups. Queue these prefs
    // before GeckoRuntime.main so the first child-process launch sees them.
    GeckoRuntime.setDefaultPrefs([
        "dom.ipc.processCount": 1,
        "dom.ipc.processPrelaunch.enabled": false,
        "dom.ipc.keepProcessesAlive.web": 0,
        "dom.ipc.keepProcessesAlive.file": 0,
        "dom.ipc.keepProcessesAlive.privilegedabout": 0
    ])
    NSLog("RootHide injection detected; disabled Gecko helper prelaunch and idle process retention.")
}

@available(iOS, introduced: 13.0, obsoleted: 14.0)
private func configureUnsandboxedAppDataDirectories() {
    guard let cachesDirectory = FileManager.default.urls(
        for: .cachesDirectory,
        in: .userDomainMask
    ).first else {
        return
    }
    
    guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
        return
    }
    
    let appDataDirectory = cachesDirectory
        .appendingPathComponent(bundleIdentifier, isDirectory: true)
        .appendingPathComponent(".mozilla", isDirectory: true)
        .appendingPathComponent("firefox", isDirectory: true)
    
    do {
        try FileManager.default.createDirectory(
            at: appDataDirectory,
            withIntermediateDirectories: true
        )
    } catch {
        return
    }
    
    setenv("MOZ_APP_DATA", appDataDirectory.path, 1)
    setenv("MOZ_LOCAL_APP_DATA", appDataDirectory.path, 1)
}

UserDataMigration.shared.run()
configureRootHideRuntimePolicy()
JITController.shared.start()
if #unavailable(iOS 14.0),
   getEntitlementValue("com.apple.private.security.no-sandbox") {
    configureUnsandboxedAppDataDirectories()
}

_ = NotificationCenter.default.addObserver(forName: Notification.Name("GeckoView.BuildMenu"), object: nil, queue: .main) { notification in
    guard let builder = notification.object as? UIMenuBuilder else { return }
    ApplicationMenuBuilder.build(with: builder)
}

GeckoRuntime.main(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
