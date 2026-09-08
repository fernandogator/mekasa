import SwiftUI
import UIKit
@testable import Mekasa

/// Hosts SwiftUI screens for snapshot tests with fixed fixtures.
@MainActor
enum SnapshotHost {
    static func makeSession(empty: Bool = false) -> AppSession {
        let session = AppSession()
        session.startUITesting(emptyInventory: empty)
        return session
    }

    static func controller<Content: View>(
        empty: Bool = false,
        @ViewBuilder content: (AppSession) -> Content
    ) -> UIViewController {
        let session = makeSession(empty: empty)
        let root = content(session)
            .environmentObject(session)
        let host = UIHostingController(rootView: root)
        host.view.frame = UIScreen.main.bounds
        return host
    }
}
