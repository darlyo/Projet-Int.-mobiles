import Kitura
import HeliumLogger
import Foundation
import SwiftRedis


// Initialize HeliumLogger
HeliumLogger.use()

// Create a new router
let router = Router()

// Handle HTTP GET requests to /
router.get("/hello") {
    request, response, next in
    response.send("Hello, World!")
    next()
}

router.get("/connect"){request, response, next in

// Start framework redis
let redis = Redis()

// Connect in local
redis.connect(host: "localhost", port: 6379) { (redisError: NSError?) in
    if let error = redisError {
        response.send("error")
    }
    else {
        print("Connected to Redis")
        // set a key
        redis.set("Redis", value: "on Swift") { (result: Bool, redisError: NSError?) in
            if let error = redisError {
                response.send("error")
            }
            // get the same key
            redis.get("Redis") { (string: RedisString?, redisError: NSError?) in
                if let error = redisError {
                    response.send("error")
                }
                else if let string = string?.asString {
                    response.send("Redis \(string)")
                }
	    }
        }
    }
}
    next()
}

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8090, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()

