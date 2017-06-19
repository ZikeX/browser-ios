/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Alamofire
import MessageUI

private let AuroraPropertyListURL = "https://people.mozilla.org/iosbuilds/FennecAurora.plist"
private let AuroraDownloadPageURL = "https://people.mozilla.org/iosbuilds/index.html"

private let AppUpdateTitle = NSLocalizedString("New version available", comment: "Prompt title for application update")
private let AppUpdateMessage = NSLocalizedString("There is a new version available of Firefox Aurora. Tap OK to go to the download page.", comment: "Prompt message for application update")
private let AppUpdateCancel = NSLocalizedString("Not Now", comment: "Label for button to cancel application update prompt")
private let AppUpdateOK = NSLocalizedString("OK", comment: "Label for OK button in the application update prompt")

class AuroraAppDelegate: AppDelegate {
    fileprivate var naggedAboutAuroraUpdate = false
    fileprivate let feedbackDelegate = FeedbackSnapshotDelegate()

	override func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		super.application(application, willFinishLaunchingWithOptions: launchOptions)

        checkForAuroraUpdate()
        registerFeedbackNotification()

        return true
    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        if !naggedAboutAuroraUpdate {
            checkForAuroraUpdate()
        }
        super.applicationDidBecomeActive(application)
    }

    func application(_ application: UIApplication, applicationWillTerminate app: UIApplication) {
        unregisterFeedbackNotification()
    }

    override func applicationWillResignActive(_ application: UIApplication) {
        super.applicationWillResignActive(application)
        unregisterFeedbackNotification()
    }

    fileprivate func registerFeedbackNotification() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.UIApplicationUserDidTakeScreenshot,
            object: nil,
            queue: OperationQueue.main) { (notification) -> Void in
                if let window = self.window {
                    UIGraphicsBeginImageContext(window.bounds.size)
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    let image = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    self.sendFeedbackMailWithImage(image!)
                }
        }
    }

    fileprivate func unregisterFeedbackNotification() {
        NotificationCenter.default.removeObserver(self,
            name: NSNotification.Name.UIApplicationUserDidTakeScreenshot, object: nil)
    }
}

extension AuroraAppDelegate: UIAlertViewDelegate {
    fileprivate func checkForAuroraUpdate() {
        if let localVersion = localVersion() {
            fetchLatestAuroraVersion() { version in
                if let remoteVersion = version {
                    if localVersion.compare(remoteVersion as String, options: NSString.CompareOptions.numeric) == ComparisonResult.orderedAscending {
                        self.naggedAboutAuroraUpdate = true

                        let alert = UIAlertView(title: AppUpdateTitle, message: AppUpdateMessage, delegate: self, cancelButtonTitle: AppUpdateCancel, otherButtonTitles: AppUpdateOK)
                        alert.show()
                    }
                }
            }
        }
    }

    fileprivate func localVersion() -> NSString? {
        return Bundle.main.object(forInfoDictionaryKey: String(kCFBundleVersionKey)) as? NSString
    }

    fileprivate func fetchLatestAuroraVersion(_ completionHandler: @escaping (NSString?) -> Void) {
		Alamofire.request(AuroraPropertyListURL, method: .get).responsePropertyList(options: PropertyListSerialization.ReadOptions(), completionHandler: { response -> Void in
            if let plist = response.result.value as? NSDictionary,
                let items = plist["items"] as? NSArray,
                let item = items[0] as? NSDictionary,
                let metadata = item["metadata"] as? NSDictionary,
                let remoteVersion = metadata["bundle-version"] as? NSString {
                completionHandler(remoteVersion)
                return
            }
            completionHandler(nil)
        })
    }

    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        if buttonIndex == 1 {
            UIApplication.shared.openURL(URL(string: AuroraDownloadPageURL)!)
        }
    }
}

extension AuroraAppDelegate {
    func sendFeedbackMailWithImage(_ image: UIImage) {
        if (MFMailComposeViewController.canSendMail()) {
            if let buildNumber = Bundle.main.object(forInfoDictionaryKey: String(kCFBundleVersionKey)) as? NSString {
                let mailComposeViewController = MFMailComposeViewController()
                mailComposeViewController.mailComposeDelegate = self.feedbackDelegate
                mailComposeViewController.setSubject("Feedback on iOS client version v\(appVersion) (\(buildNumber))")
                mailComposeViewController.setToRecipients(["ios-feedback@mozilla.com"])

                if let imageData = UIImagePNGRepresentation(image) {
                    mailComposeViewController.addAttachmentData(imageData, mimeType: "image/png", fileName: "feedback.png")
                    window?.rootViewController?.present(mailComposeViewController, animated: true, completion: nil)
                }
            }
        }
    }
}

fileprivate class FeedbackSnapshotDelegate: NSObject, MFMailComposeViewControllerDelegate {
    @objc func mailComposeController(_ mailComposeViewController: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        mailComposeViewController.dismiss(animated: true, completion: nil)
    }
}
