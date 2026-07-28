import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    var backgroundSessionCompletionHandler: (() -> Void)?

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        backgroundSessionCompletionHandler = completionHandler
        UploadManager.shared.backgroundEventsCompletionHandler = { [weak self] in
            self?.backgroundSessionCompletionHandler?()
            self?.backgroundSessionCompletionHandler = nil
        }
        UploadManager.shared.restoreBackgroundTasks()
    }
}

@main
struct ACEReviewApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = SessionStore()
    @StateObject private var uploads = UploadManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(uploads)
                .preferredColorScheme(.light)
        }
    }
}

