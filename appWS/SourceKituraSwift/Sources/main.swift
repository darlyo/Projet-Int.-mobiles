import Kitura
import SwiftRedis
import SwiftyJSON


// Create a new router
let router = Router()

// Handle HTTP GET requests to /
router.get("/app") {
    request, response, next in
    response.send("Hello, World!")
    next()
}

router.get("/app/:name") { request, response, _ in
    let name = request.parameters["name"] ?? ""
    try response.send("Hello \(name)").end()
}


// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8090, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()
