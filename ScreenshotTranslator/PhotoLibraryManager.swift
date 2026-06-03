import Foundation
import Photos
import UIKit

class PhotoLibraryManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var screenshots: [PHAsset] = []
    @Published var isCheckingForRecent = false
    
    init() {
        checkStatus()
    }
    
    func checkStatus() {
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestAccess(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
                let granted = status == .authorized || status == .limited
                if granted {
                    self.fetchScreenshots()
                }
                completion(granted)
            }
        }
    }
    
    func fetchScreenshots() {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 30
        
        // Try to fetch from Screenshots smart album
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil)
        
        if let screenshotAlbum = smartAlbums.firstObject {
            let assets = PHAsset.fetchAssets(in: screenshotAlbum, options: fetchOptions)
            var fetched: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                fetched.append(asset)
            }
            DispatchQueue.main.async {
                self.screenshots = fetched
            }
        } else {
            // Fallback: Fetch all images, sorted by newest first
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var fetched: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                fetched.append(asset)
            }
            DispatchQueue.main.async {
                self.screenshots = fetched
            }
        }
    }
    
    /// Checks for a screenshot taken in the last 15 minutes (900 seconds).
    /// If found, returns the asset.
    func detectRecentScreenshot(maxAgeSeconds: TimeInterval = 900, completion: @escaping (PHAsset?) -> Void) {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            completion(nil)
            return
        }
        
        isCheckingForRecent = true
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumScreenshots, options: nil)
        let assets: PHFetchResult<PHAsset>
        
        if let screenshotAlbum = smartAlbums.firstObject {
            assets = PHAsset.fetchAssets(in: screenshotAlbum, options: fetchOptions)
        } else {
            assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        }
        
        self.isCheckingForRecent = false
        
        guard let latestAsset = assets.firstObject else {
            completion(nil)
            return
        }
        
        let assetDate = latestAsset.creationDate ?? Date()
        let age = Date().timeIntervalSince(assetDate)
        
        if age >= 0 && age < maxAgeSeconds {
            completion(latestAsset)
        } else {
            completion(nil)
        }
    }
    
    func loadImage(for asset: PHAsset, targetSize: CGSize = PHImageManagerMaximumSize, completion: @escaping (UIImage?) -> Void) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
}
