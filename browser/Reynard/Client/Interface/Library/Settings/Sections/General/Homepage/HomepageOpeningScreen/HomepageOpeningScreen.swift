//
//  HomepageOpeningScreen.swift
//  Reynard
//
//  Created by Minh Ton on 27/6/26.
//

enum HomepageOpeningScreen: String, CaseIterable {
    case homepage
    case lastTab
    case customURL
    
    var title: String {
        switch self {
        case .homepage:
            return NSLocalizedString("Homepage", comment: "")
        case .lastTab:
            return "启动时打开上次页面"
        case .customURL:
            return "启动时打开指定网页"
        }
    }
}
