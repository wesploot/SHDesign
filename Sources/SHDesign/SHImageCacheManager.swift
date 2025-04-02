//
//  File.swift
//  
//
//  Created by Sahib Hussain on 25/05/24.
//

import UIKit
import AVKit
import Kingfisher

public class SHImageCacheManager {
    
    public static let shared = SHImageCacheManager()
    
    private var assets: [String: UIImage] = [:]
    private init() {}
    
    public func initialise() {
        ImageCache.default.memoryStorage.config.totalCostLimit = 300 * 1024 * 1024
        ImageCache.default.memoryStorage.config.countLimit = 150
        ImageCache.default.diskStorage.config.sizeLimit = 1000 * 1024 * 1024
        ImageCache.default.memoryStorage.config.expiration = .seconds(600)
        ImageCache.default.diskStorage.config.expiration = .days(20)
    }
    
    public func clearAllCache() {
        ImageCache.default.clearMemoryCache()
        ImageCache.default.clearDiskCache { print("Done") }
        
    }
    
    public func clearExpiredCache() {
        ImageCache.default.cleanExpiredMemoryCache()
        ImageCache.default.cleanExpiredDiskCache { print("Done") }
    }
    
    public func cacheSize() {
        ImageCache.default.calculateDiskStorageSize { result in
            switch result {
            case .success(let size):
                print("Disk cache size: \(Double(size) / 1024 / 1024) MB")
            case .failure(let error):
                print(error)
            }
        }
    }
    
    public func localFetchAsset(for url: URL) -> UIImage? { assets[url.absoluteString] }
    
    public func fetchVideoThumbnail(for url: URL, completion: ((UIImage?) -> Void)? = nil) {
        
        if let image = assets[url.absoluteString] { completion?(image); return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            
            var image: UIImage? = nil
            let timestamp = CMTime(seconds: 1, preferredTimescale: 60)
            if let imageRef = try? generator.copyCGImage(at: timestamp, actualTime: nil) { 
                let localImage = UIImage(cgImage: imageRef)
                image = localImage
                self?.assets[url.absoluteString] = localImage
            }
            DispatchQueue.main.async { completion?(image) }
        }
        
    }
    
}

public extension UIImageView {
    
    func videoSnapshot(_ url: URL?, placeholder: UIImage) {

        self.image = placeholder
        guard let vidURL = url else { return }
        SHImageCacheManager.shared.fetchVideoThumbnail(for: vidURL) { [weak self] image in
            self?.image = image
        }
        
    }
    
}

class BlurHashCache {
    
    static let shared = BlurHashCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024
    }
    
    func image(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
}

extension UIImageView {
    
    func setWebImage(_ url: URL?, placeholder: UIImage, hash: String? = nil) {
        
        guard let hash else {
            setImage(with: url, placeholder: placeholder)
            return
        }
        
        if let image = BlurHashCache.shared.image(forKey: hash) {
            setImage(with: url, placeholder: image)
            return
        }
        
        AsyncTask.globalThread { [weak self] in
            guard let image = UIImage(blurHash: hash, size: .init(width: 5, height: 5)) else {
                AsyncTask.mainThread { self?.setImage(with: url, placeholder: placeholder) }
                return
            }
            BlurHashCache.shared.setImage(image, forKey: hash)
            AsyncTask.mainThread { self?.setImage(with: url, placeholder: image) }
        }
        
    }
    
    private func setImage(with url: URL?, placeholder: UIImage) {
        let processor = DownsamplingImageProcessor(size: self.bounds.size)
        self.kf.setImage(with: url, placeholder: placeholder, options: [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .transition(.fade(0.5)),
            .cacheOriginalImage
        ])
    }
    
}

extension UIButton {
    
    func setWebImage(_ url: URL?, placeholder: UIImage, hash: String? = nil) {
        
        guard let hash else {
            setImage(with: url, placeholder: placeholder)
            return
        }
        
        if let image = BlurHashCache.shared.image(forKey: hash) {
            setImage(with: url, placeholder: image)
            return
        }
        
        AsyncTask.globalThread { [weak self] in
            guard let image = UIImage(blurHash: hash, size: .init(width: 5, height: 5)) else {
                AsyncTask.mainThread { self?.setImage(with: url, placeholder: placeholder) }
                return
            }
            BlurHashCache.shared.setImage(image, forKey: hash)
            AsyncTask.mainThread { self?.setImage(with: url, placeholder: image) }
        }
        
    }
    
    private func setImage(with url: URL?, placeholder: UIImage) {
        let processor = DownsamplingImageProcessor(size: self.bounds.size)
        self.kf.setImage(with: url, for: .normal, placeholder: placeholder, options: [
            .processor(processor),
            .scaleFactor(UIScreen.main.scale),
            .transition(.fade(0.5)),
            .cacheOriginalImage
        ])
    }
    
}
