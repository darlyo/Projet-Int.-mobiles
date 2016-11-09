import PackageDescription


let package = Package(
    name: "projectTest",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1, minor: 1),
        .Package(url: "https://github.com/IBM-Swift/Kitura-redis.git", majorVersion: 1, minor: 1)
	])
