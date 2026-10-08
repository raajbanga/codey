import UIKit

/// What the UI shows for the account (BackendFacade.authState).
enum AuthState: Equatable {
    case signedOut
    case signingIn
    case signedIn(AppUser)
    case error(String)

    var user: AppUser? {
        if case .signedIn(let user) = self { return user }
        return nil
    }
}

extension UIApplication {
    /// The view controller to present Google sign-in from.
    var topViewController: UIViewController? {
        let scene = connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            ?? connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
