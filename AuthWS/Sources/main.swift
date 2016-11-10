import Kitura
import HeliumLogger
import Foundation
import SwiftRedis

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

let Auth_port = 6379 as Int32
let Auth_host = "localhost"

func generateToken() -> String {

	let length = 8
    let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let len = UInt32(letters.length)

    var randomString = ""

    for _ in 0 ..< length {
#if os(Linux)
        let rand = Int(random() % letters.length)
#else
		let rand = Int(arc4random_uniform(len))
#endif

        var nextChar = letters.character(at: Int(rand))
        randomString += NSString(characters: &nextChar, length: 1) as String
        //randomString += String(nextChar)
    }

    return randomString
}

// Initialize HeliumLogger
HeliumLogger.use()

// Create a new router
let router = Router()

// Handle HTTP GET requests to /
router.get("/hello") {
    request, response, next in
    //let token = generateToken()
    let rand = random()
    response.send("Hello, World!")
    response.send("token : \(rand)")
    next()
}

router.post("/check/:token"){request, response, next in
    let token = request.parameters["token"] ?? ""
	// Start framework redisError
	let redis = Redis()

	// Connect in local
	redis.connect(host: Auth_host, port: Auth_port) { (redisError: NSError?) in
	    if let error = redisError {
	        response.send("error")
	    }
	    else {
	        print("Connected to Redis")
	        // set a key
	        redis.ttl(token) { (time: TimeInterval?, redisError: NSError?) in
	            if let error = redisError {
	                response.send("error")
	            }
	            else if time! == -1 {
	                response.send("token invalide, time expire")
	            }
	            else if time! == -2 {
	                response.send("token : \(token) invalide")
	            }
	            else{
	                response.send("Check OK, token valide, time remaning : \(time)")
	            }
	        }
	    }
	}
    next()
}

router.post("/connect") { request, response, next in
    guard let parsedBody = request.body else {
        next()
        return
    }

    switch(parsedBody) {
    case .json(let jsonBody):
        let user = jsonBody["user"].string ?? ""
        let password = jsonBody["password"].string ?? ""

		let redis = Redis()
        redis.connect(host: Auth_host, port: Auth_port) { (redisError: NSError?) in
		    if let error = redisError {
		        response.send("error")
		    }
		    redis.get(user) { (pass: RedisString?, redisError: NSError?) in
			    if let error = redisError {
			        response.send("error")
			    }
			    else if pass!.asString == password {
			        response.send("connected")
			    }
			    else {
			        response.send("connect echec")
			    }
			}
        }
    default:
        break
    }
    next()
}

router.post("/disconnect") { request, response, next in
    guard let parsedBody = request.body else {
        next()
        return
    }

    switch(parsedBody) {
    case .json(let jsonBody):
            let name = jsonBody["name"].string ?? ""
            try response.send("Hello \(name)").end()
    default:
        break
    }
    next()
}

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8090, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()