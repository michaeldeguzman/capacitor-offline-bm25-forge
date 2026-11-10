import UIKit

/// Scene life cycle entry point. SDKs from Xcode 27 refuse to launch an app without one.
/// UISceneStoryboardFile in Info.plist makes UIKit create the window from Main.storyboard.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
}
