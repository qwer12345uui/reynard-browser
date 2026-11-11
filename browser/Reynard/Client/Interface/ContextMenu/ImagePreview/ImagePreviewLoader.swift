//
//  ImagePreviewLoader.swift
//  Reynard
//
//  Created by Minh Ton on 16/6/26.
//

import GeckoView
import UIKit

struct ImagePreviewLoader {
    static func image(from url: URL, in session: GeckoSession) async -> UIImage? {
        if url.isFileURL {
            return UIImage(contentsOfFile: url.path)
        }
        
        if url.scheme?.lowercased() == "data" {
            return imageFromDataURL(url.absoluteString)
        }
        
        guard let data = try? await session.fetchImageData(from: url) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    private static func imageFromDataURL(_ value: String) -> UIImage? {
        guard let commaIndex = value.firstIndex(of: ",") else {
            return nil
        }
        
        let payload = value[value.index(after: commaIndex)...]
        let data: Data?
        if value[..<commaIndex].lowercased().contains(";base64") {
            data = Data(base64Encoded: String(payload))
        } else {
            data = String(payload).removingPercentEncoding?.data(using: .utf8)
        }
        
        guard let data else {
            return nil
        }
        return UIImage(data: data)
    }
}
