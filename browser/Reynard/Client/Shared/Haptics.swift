//
//  Haptics.swift
//  Reynard
//
//  Created by Minh Ton on 18/6/26.
//

import UIKit

enum Haptics {
    private static let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    
    static func prepareRigid() {
        guard Prefs.BrowserFeatureSettings.touchFeedbackEnabled else {
            return
        }
        impactGenerator.prepare()
    }
    
    static func rigid() {
        guard Prefs.BrowserFeatureSettings.touchFeedbackEnabled else {
            return
        }
        impactGenerator.impactOccurred()
    }
    
    static func success() {
        guard Prefs.BrowserFeatureSettings.touchFeedbackEnabled else {
            return
        }
        notificationGenerator.notificationOccurred(.success)
    }
}
