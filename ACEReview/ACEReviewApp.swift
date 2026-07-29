import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        UploadManager.shared.handleBackgroundEvents(
            identifier: identifier,
            completionHandler: completionHandler
        )
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
