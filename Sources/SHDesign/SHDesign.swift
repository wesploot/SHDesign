//
//  SHDesign.swift
//  SHDesign
//
//  Created by Sahib Hussain on 22/06/23.
//

import Foundation
import AVFoundation
import SwiftSoup


public enum PreviewType: String, Codable {
    
    case product, website, article, book, profile, unknown
    
    case movie = "video.movie"
    case tvShow = "video.tv_show"
    case video = "video.other"
    
    case song = "music.song"
    case album = "music.album"
    case playlist = "music.playlist"
    case radioStation = "music.radio_station"
    
}

public struct LinkPreviewModal: Codable {
    
    public let id: UUID
    public let url: URL
    public var type: PreviewType
    
    public let siteName: String?
    public let title: String?
    public let description: String?
    
    public let imageURL: URL?
    public let videoURL: URL?
    
    public let locale: String?
    
    public let price: String?
    public let currentcy: String?
    
    init(_ url: URL, type: PreviewType, siteName: String?, title: String?, description: String?, imageURL: URL?, videoURL: URL?, locale: String?, price: String?, currentcy: String?) {
        self.id = UUID()
        self.url = url
        self.type = type
        self.siteName = siteName
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.locale = locale
        self.price = price
        self.currentcy = currentcy
    }
    
}

public class SHDesign {
    
    public static let shared = SHDesign()
    private init() {}
    
    public func playSystemAudio(_ id: SystemSoundID) {
        AudioServicesPlaySystemSound(id)
    }
    
    public func fetchMetadata(of url: URL, completion: @escaping (LinkPreviewModal?) -> Void) {
        DispatchQueue.global(qos: .background)
            .async { [weak self] in
                URLSession.shared.dataTask(with: .init(url: url)) { data, response, error in
                    guard let data,
                          let htmlString = String(data: data, encoding: .utf8),
                          let preview = self?.parse(htmlString, url: url) else { completion(nil); return }
                    completion(preview)
                }.resume()
            }
    }
    
    private func parse(_ html: String, url: URL) -> LinkPreviewModal? {
        
        guard let doc = try? SwiftSoup.parse(html), let metas = try? doc.select("meta") else { return nil }
        
        var type: PreviewType = .unknown
        
        var siteName: String? = nil
        var title = try? doc.title()
        var description: String? = nil
        
        var imageURL: URL? = nil
        var videoURL: URL? = nil
        
        var locale: String? = nil
        
        var price: String? = nil
        var currency: String? = nil
        
        for meta in metas.array() {
            
            let propertyName = try? meta.attr("property")
            let content = try? meta.attr("content")
            let prop = try? meta.attr("itemprop")
            let metaName = try? meta.attr("name")
            
            // MARK: type
            if let propertyName, let content, propertyName == "og:type" {
                type = .init(rawValue: content) ?? .unknown
            }
            
            // MARK: site name
            if let propertyName, let content, (propertyName == "og:site_name" || propertyName == "twitter:site_name") {
                siteName = content
            }
            
            // MARK: title
            if let propertyName, let content, (propertyName == "og:title" || propertyName == "twitter:title") {
                title = content
            }
            
            // MARK: description
            if let propertyName, let content, (propertyName == "og:description" || propertyName == "twitter:description") {
                description = content
            }
            
            if let metaName, let content, (metaName == "description" || metaName == "twitter:description" || metaName == "og:description") {
                description = content
            }
            
            // MARK: imageURL
            if let prop, let content, prop == "image", let host = url.host  {
                imageURL = URL(string: content) ?? URL(string: host + content )
            }
            
            if let propertyName, let content, (propertyName == "og:image" || propertyName == "twitter:image") {
                imageURL = URL(string: content)
            }
            
            // MARK: videoIRL
            if let propertyName, let content, propertyName == "og:video" {
                videoURL = URL(string: content)
            }
            
            // MARK: locale
            if let propertyName, let content, propertyName == "og:locale" {
                locale = content
            }
            
            // MARK: price
            if let propertyName, let content, propertyName == "product:price:amount" {
                price = content
            }
            
            // MARK: currency
            if let propertyName, let content, propertyName == "product:price:currency" {
                currency = content
            }
            
            
        }
        
        
        // youtube image
        if let linkTags = try? doc.select("link") {
            for link in linkTags {
                let asName = try? link.attr("as")
                let href = try? link.attr("href")
                if let asName, let href, asName == "image" {
                    imageURL = URL(string: href)
                }
            }
        }
        
        
        return .init(url, type: type, siteName: siteName, title: title, description: description, imageURL: imageURL, videoURL: videoURL, locale: locale, price: price, currentcy: currency)
        
    }
    
}

public struct AsyncTask {
    
    public static func mainThread(_ delay: TimeInterval = 0, block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
    }
    
    public static func globalThread(_ delay: TimeInterval = 0, qos: DispatchQoS.QoSClass = .background, block: @escaping () -> Void) {
        DispatchQueue.global(qos: qos).asyncAfter(deadline: .now() + delay, execute: block)
    }
    
}
