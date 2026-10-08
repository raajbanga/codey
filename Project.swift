import ProjectDescription

// Stable reverse-DNS IDs (B10). The Google iOS OAuth client is bound to the
// app ID, so don't change it once that client exists.
let appBundleId = "edu.wku.cs360.codey"

let project = Project(
    name: "codey",
    options: .options(
        automaticSchemesOptions: .enabled(codeCoverageEnabled: true)
    ),
    settings: .settings(
        base: ["SWIFT_VERSION": "5"],
        configurations: [
            .debug(name: .debug, xcconfig: "Config/Base.xcconfig"),
            .release(name: .release, xcconfig: "Config/Base.xcconfig"),
        ]
    ),
    targets: [
        .target(
            name: "codey",
            destinations: [.iPhone],
            product: .app,
            bundleId: appBundleId,
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(
                with: [
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
                ]
            ),
            buildableFolders: [
                "codey/Sources",
                "codey/Resources",
            ],
            dependencies: [
                .external(name: "Textual"),
                .external(name: "Runestone"),
                .external(name: "TreeSitterSwiftRunestone"),
                .external(name: "TreeSitterPythonRunestone"),
                .external(name: "TreeSitterJavaRunestone"),
                .external(name: "TreeSitterCPPRunestone"),
            ]
        ),
        .target(
            name: "codeyTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "\(appBundleId).tests",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .default,
            buildableFolders: [
                "codey/Tests"
            ],
            dependencies: [.target(name: "codey")]
        ),
    ]
)
