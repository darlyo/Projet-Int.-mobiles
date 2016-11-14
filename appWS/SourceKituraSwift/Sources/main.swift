import Kitura
import SwiftRedis
import SwiftyJSON
import Foundation


// Create a new router
let router = Router()

/////////////////////////////////////////////////////////////////////////////////////////////////////////// Connection to BDD Redis
let redis = Redis()

redis.connect(host: "", port: 6379) { (redisError: NSError?) in   
    if let error = redisError {
        print(error)
    }
    else {
        print("Connected to Redis")
        // set a key
        redis.set("Redis", value: "on Swift") { (result: Bool, redisError: NSError?) in
            if let error = redisError {
                print(error)
            }
            // get the same key
            redis.get("Redis") { (string: RedisString?, redisError: NSError?) in
                if let error = redisError {
                    print(error)
                }
                else if let string = string?.asString {
                    print("Redis \(string)")
                }
            }
        }
    }
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// Test

// Handle HTTP GET requests to /
// router.get("/app") {
//  redis.connect(host: "", port: 6379);
//     request, response, next in
//     response.send("Hello, World!")
//     next()
// }

// router.get("/app/:name") { request, response, _ in
//     let name = request.parameters["name"] ?? ""
//     try response.send("Hello \(name)").end()
// }

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

router.get("/app/message") { request, response, next in
    guard let parsedBody = request.body else {
        next()
        return 
    //{"longitude": "132.12", "latitude": "50.56", "radius": "35.24", "date": "12/11/17", "hours": "16.05"}
    }
    switch(parsedBody) {
    case .json(let jsonBody):
            let longitude = jsonBody["longitude"].string ?? ""
            let latitude = jsonBody["latitude"].string ?? ""
            let radius = jsonBody["radius"].string ?? ""
            let date = jsonBody["date"].string ?? ""
            let hours = jsonBody["hours"].string ?? ""
    }
    //faire le calcul pour la longitude/latitude et radius 

    //Recevoir les topics via la BDD

}
    

router.post("/app/message") { request, response, next in
    guard let parsedBody = request.body else {
        next()
        return
    }

    //Recuperer le nombre de clé disponible dans la BDD
    var keys = 0
    redis.exists(String(keys)) {( nb: Int? , redisError: NSError?) in
        if let error = redisError {
            response.send("Error")
        }
        else if let nbKeys = nb {

        var newKey = 0
        var longit = ""
        var latit = ""
        var pop = ""
        var d = ""
        var h = ""
        var top = ""
        switch(parsedBody) {
        case .json(let jsonBody):
                longit = jsonBody["longitude"].string ?? ""
                latit = jsonBody["latitude"].string ?? ""
                pop = jsonBody["popularity"].string ?? ""
                d = jsonBody["date"].string ?? ""
                h = jsonBody["hours"].string ?? ""
                top = jsonBody["topic"].string ?? ""


        default:
            break

        }
    
        newKey = nbKeys + 1; //variable pour attribuer un nombre pour la clé du nouveau message
        //Envoyer le nouveau message à la BDD 
        redis.hmset(newKey, fieldValuePairs: ("longitude", longit), ("latitude", latit), ("popularity", pop), ("date", d), ("hours", h), ("topic", top)) {(result: Bool?,redisError: NSError?) in
            if let error = redisError {
                response.send("Error")
            }
        }

        next()

        }
    }
}

//////////////////////////////////////////////////////////////////////////////////////////

router.post("app/mess/key") { request, response, next in
    guard let parsedBody = request.body else {
        next()
        return
    }

    switch(parsedBody) {
    case .json(let jsonBody):
        let idMessage = jsonBody["key"].string ?? "" //Recupérer la valeur de l'id du topic
            redis.hincr(idMessage, field: "popularity", by: 1) {(value: Int?, redisError: NSError?) in//Incrémenter la valeur de la pop en fonction de l'ID du topic
            
                if let error = redisError {
                    try response.send("Error").end() 
                }
            }
    }   
}


// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8090, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()
