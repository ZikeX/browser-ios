/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Storage
import WebImage

public extension UIImageView {
    public func setIcon(_ icon: Favicon?, withPlaceholder placeholder: UIImage) {
        if let icon = icon {
            let imageURL = URL(string: icon.url)
			self.sd_setImage(with: imageURL, placeholderImage: placeholder)
            return
        }
        self.image = placeholder
    }
}


open class ImageOperation : NSObject, SDWebImageOperation {
    open var cacheOperation: Operation?

    var cancelled: Bool {
        if let cacheOperation = cacheOperation {
            return cacheOperation.isCancelled
        }
        return false
    }

    @objc open func cancel() {
        if let cacheOperation = cacheOperation {
            cacheOperation.cancel()
        }
    }
}

// This is an extension to SDWebImage's api to allow passing in a cache to be used for lookup.
public typealias CompletionBlock = (_ img: UIImage?, _ err: NSError, _ type: SDImageCacheType, _ key: String) -> Void
extension UIImageView {
    // This is a helper function for custom async loaders. It starts an operation that will check for the image in
    // a cache (either one passed in or the default if none is specified). If its found in the cache its returned,
    // otherwise, block is run and should return an image to show.
    fileprivate func runBlockIfNotInCache(_ key: String, cache: SDImageCache, completed: @escaping CompletionBlock, block: @escaping () -> UIImage?) {
        self.sd_cancelCurrentImageLoad()

        let operation = ImageOperation()

        operation.cacheOperation = cache.queryDiskCache(forKey: key, done: { (image, cacheType) -> Void in
            let err = NSError(domain: "UIImage+Extensions.runBlockIfNotInCache", code: 0, userInfo: nil)
            // If this was cancelled, don't bother notifying the caller
            if operation.cancelled {
                return
            }

            // If it was found in the cache, we can just use it
            if let image = image {
                self.image = image
                self.setNeedsLayout()
            } else {
                // Otherwise, the block has a chance to load it
                let image = block()
                if image != nil {
                    self.image = image
                    cache.store(image, forKey: key)
                }
            }

            completed(image, err, cacheType, key)
        })

        self.sd_setImageLoadOperation(operation, forKey: "UIImageViewImageLoad")
    }

    public func moz_getImageFromCache(_ key: String, cache: SDImageCache, completed: @escaping CompletionBlock) {
        // This cache is filled outside of here. If we don't find the key in it, nothing to do here.
        runBlockIfNotInCache(key, cache: cache, completed: completed) { _ in return nil}
    }
}
