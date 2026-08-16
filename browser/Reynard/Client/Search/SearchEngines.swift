//
//  SearchEngines.swift
//  Reynard
//
//  Created by Minh Ton on 18/6/26.
//

import Foundation

enum SearchEngine: String, CaseIterable {
    case google
    case baidu
    case toutiao
    case so360
    case sogou
    case bing
    case quark
    case yahoo
    case brave
    case duckDuckGo
    case ecosia
    case startpage
    case custom
    
    var displayName: String {
        switch self {
        case .google:
            return "谷歌 Google"
        case .baidu:
            return "百度"
        case .toutiao:
            return "头条"
        case .so360:
            return "360 搜索"
        case .sogou:
            return "搜狗"
        case .bing:
            return "Bing"
        case .quark:
            return "夸克"
        case .yahoo:
            return "Yahoo"
        case .brave:
            return "Brave"
        case .duckDuckGo:
            return "DuckDuckGo"
        case .ecosia:
            return "Ecosia"
        case .startpage:
            return "Startpage"
        case .custom:
            return NSLocalizedString("Custom", comment: "Search engine option")
        }
    }
    
    static func destination(for query: String) -> String {
        let components = query.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
        let shortcutEngine = components.first.flatMap { shortcutAliases[$0.lowercased()] }
        let searchTerms = shortcutEngine != nil && components.count == 2 ? String(components[1]) : query
        let template = shortcutEngine?.queryTemplate ?? selectedQueryTemplate
        let escapedQuery = searchTerms.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return template.replacingOccurrences(of: "%s", with: escapedQuery)
    }

    private static let shortcutAliases: [String: SearchEngine] = [
        "bd": .baidu,
        "baidu": .baidu,
        "tt": .toutiao,
        "toutiao": .toutiao,
        "gg": .google,
        "google": .google,
        "so": .so360,
        "360": .so360,
        "sogou": .sogou,
        "bing": .bing,
        "kk": .quark,
        "quark": .quark,
    ]
    
    static func canSearch(using customQueryTemplate: String) -> Bool {
        let normalizedTemplate = customQueryTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedTemplate.contains("%s") else {
            return false
        }
        
        let exampleDestination = normalizedTemplate.replacingOccurrences(of: "%s", with: "reynard")
        return URLUtils.normalizedCustomURL(from: exampleDestination) != nil
    }
    
    private var queryTemplate: String? {
        switch self {
        case .google:
            return "https://www.google.com/search?q=%s"
        case .baidu:
            return "https://m.baidu.com/s?word=%s"
        case .toutiao:
            return "https://so.toutiao.com/search?keyword=%s"
        case .so360:
            return "https://m.so.com/s?q=%s"
        case .sogou:
            return "https://m.sogou.com/web/searchList.jsp?keyword=%s"
        case .bing:
            return "https://www.bing.com/search?q=%s"
        case .quark:
            return "https://quark.sm.cn/s?q=%s"
        case .yahoo:
            return "https://search.yahoo.com/search?p=%s"
        case .brave:
            return "https://search.brave.com/search?q=%s"
        case .duckDuckGo:
            return "https://duckduckgo.com/?q=%s"
        case .ecosia:
            return "https://www.ecosia.org/search?q=%s"
        case .startpage:
            return "https://www.startpage.com/sp/search?query=%s"
        case .custom:
            return nil
        }
    }
    
    private static var selectedQueryTemplate: String {
        switch Prefs.SearchSettings.searchEngine {
        case .custom:
            let customQueryTemplate = Prefs.SearchSettings.customSearchTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard canSearch(using: customQueryTemplate) else {
                return SearchEngine.google.queryTemplate!
            }
            
            let exampleDestination = customQueryTemplate.replacingOccurrences(of: "%s", with: "reynard")
            return URLUtils.isWebURL(exampleDestination) ? customQueryTemplate : "https://\(customQueryTemplate)"
        case let engine:
            return engine.queryTemplate ?? SearchEngine.google.queryTemplate!
        }
    }
}
