import Foundation
import Testing
@testable import codey

/// BUG-01 regression: GoogleSignIn opens its sign-in page through an
/// Objective-C category on AppAuth's `OIDAuthorizationService`. Packages link
/// statically, so without `-ObjC` in OTHER_LDFLAGS the linker strips that
/// category and tapping "Sign in with Google" crashed with
/// "unrecognized selector".
struct GoogleSignInLinkTests {

    @Test func appAuthPresentCategoryIsLinked() throws {
        let cls: AnyClass = try #require(NSClassFromString("OIDAuthorizationService"))
        let selector = NSSelectorFromString(
            "presentAuthorizationRequest:presentingViewController:callback:"
        )
        #expect((cls as AnyObject).responds(to: selector))
    }

    @Test func urlSchemeMatchesReversedClientID() throws {
        let info = try #require(Bundle.main.infoDictionary)
        // Local-only builds (no Secrets.xcconfig, e.g. CI) leave this empty
        // and never show the Google button, so there is nothing to check.
        guard let reversed = info["GOOGLE_REVERSED_CLIENT_ID"] as? String,
              !reversed.isEmpty else { return }
        let types = info["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes.contains(reversed))
    }
}
