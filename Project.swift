import ProjectDescription

let project = Project(
    name: "codey",
    targets: [
        .target(
            name: "codey",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.tuist.codey",
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            buildableFolders: [
                "codey/Sources",
                "codey/Resources",
            ],
            dependencies: []
        ),
        .target(
            name: "codeyTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.tuist.codeyTests",
            infoPlist: .default,
            buildableFolders: [
                "codey/Tests"
            ],
            dependencies: [.target(name: "codey")]
        ),
    ]
)
