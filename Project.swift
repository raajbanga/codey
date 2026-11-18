import ProjectDescription

// Stable reverse-DNS IDs (B10). The Google iOS OAuth client is bound to the
// app ID, so don't change it once that client exists.
let appBundleId = "edu.wku.cs360.codey"

let project = Project(
    name: "codey",
    options: .options(
        automaticSchemesOptions: .disabled
    ),
    settings: .settings(
        base: ["SWIFT_VERSION": "6"],
        configurations: [
            .debug(name: .debug, xcconfig: "Config/Base.xcconfig"),
            .release(name: .release, xcconfig: "Config/Base.xcconfig"),
        ]
    ),
    targets: [
        .target(
            name: "codey",
            // Mac: the iPad app through Mac Catalyst (regular width, so the
            // iPad layout; a wide window splits into two columns).
            destinations: [.iPhone, .iPad, .macCatalyst],
            product: .app,
            bundleId: appBundleId,
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(
                with: [
                    // iPhone is portrait-only (S45); iPad and Mac rotate freely.
                    "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
                    "UISupportedInterfaceOrientations~ipad": [
                        "UIInterfaceOrientationPortrait",
                        "UIInterfaceOrientationPortraitUpsideDown",
                        "UIInterfaceOrientationLandscapeLeft",
                        "UIInterfaceOrientationLandscapeRight",
                    ],
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                    // Filled from Config/Secrets.xcconfig; empty = local-only mode.
                    "SUPABASE_URL": "$(SUPABASE_URL)",
                    "SUPABASE_ANON_KEY": "$(SUPABASE_ANON_KEY)",
                    "GOOGLE_IOS_CLIENT_ID": "$(GOOGLE_IOS_CLIENT_ID)",
                    "GOOGLE_REVERSED_CLIENT_ID": "$(GOOGLE_REVERSED_CLIENT_ID)",
                    "GOOGLE_SERVER_CLIENT_ID": "$(GOOGLE_SERVER_CLIENT_ID)",
                    // Ask AI (S39); empty key = the Ask AI button is hidden.
                    "OPENROUTER_API_KEY": "$(OPENROUTER_API_KEY)",
                    "OPENROUTER_MODEL": "$(OPENROUTER_MODEL)",
                    // GoogleSignIn reads these; the reversed client ID is the
                    // OAuth redirect scheme. No ATS exceptions (NFR-06).
                    "GIDClientID": "$(GOOGLE_IOS_CLIENT_ID)",
                    "GIDServerClientID": "$(GOOGLE_SERVER_CLIENT_ID)",
                    "CFBundleURLTypes": [
                        [
                            "CFBundleURLName": "google-sign-in",
                            "CFBundleURLSchemes": ["$(GOOGLE_REVERSED_CLIENT_ID)"],
                        ],
                    ],
                ]
            ),
            buildableFolders: [
                "codey/Sources",
                "codey/Resources",
            ],
            // Keychain Sharing (own group): needed for sign-in on Mac Catalyst.
            entitlements: .file(path: "codey/codey.entitlements"),
            dependencies: [
                .external(name: "Textual"),
                .external(name: "Runestone"),
                .external(name: "TreeSitterSwiftRunestone"),
                .external(name: "TreeSitterPythonRunestone"),
                .external(name: "TreeSitterJavaRunestone"),
                .external(name: "TreeSitterCPPRunestone"),
                .external(name: "Supabase"),
                .external(name: "GoogleSignIn"),
            ],
            // BUG-01: packages link as static frameworks, and the linker drops
            // Objective-C categories from static code unless -ObjC is set.
            // GoogleSignIn presents its sign-in page through an AppAuth category
            // (OIDAuthorizationService+IOS); without it the Google button
            // crashed with "unrecognized selector".
            //
            // Tuist signs Mac Catalyst "to Run Locally", which can't carry the
            // keychain entitlement sign-in needs; sign it like the iPhone build.
            settings: .settings(base: [
                "OTHER_LDFLAGS": "$(inherited) -ObjC",
                "CODE_SIGN_IDENTITY[sdk=macosx*]": "Apple Development",
            ])
        ),
        .target(
            name: "codeyTests",
            destinations: [.iPhone, .iPad],
            product: .unitTests,
            bundleId: "\(appBundleId).tests",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .default,
            buildableFolders: [
                "codey/Tests"
            ],
            dependencies: [.target(name: "codey")]
        ),
        .target(
            name: "codeyUITests",
            destinations: [.iPhone, .iPad],
            product: .uiTests,
            bundleId: "\(appBundleId).uitests",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .default,
            buildableFolders: [
                "codey/UITests"
            ],
            dependencies: [.target(name: "codey")]
        ),
    ],
    // One shared scheme. Run uses Release, so the app on a phone is the build
    // we ship (no DEBUG test clients, optimized); tests stay on Debug, which
    // the UI tests' launch arguments need.
    schemes: [
        .scheme(
            name: "codey",
            shared: true,
            buildAction: .buildAction(targets: ["codey"]),
            testAction: .targets(
                ["codeyTests", "codeyUITests"],
                configuration: .debug,
                options: .options(coverage: true, codeCoverageTargets: ["codey"])
            ),
            runAction: .runAction(configuration: .release, executable: "codey"),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(configuration: .release, executable: "codey"),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
    ],
    // Xcode already generates typed asset symbols (Color(.brand)); Tuist's
    // copy (Derived/Sources/TuistAssets+Codey.swift) went unused.
    resourceSynthesizers: []
)
