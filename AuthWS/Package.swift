import PackageDescription

let package = Package(
    name: "AuthWS",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1, minor: 1)
    ])

