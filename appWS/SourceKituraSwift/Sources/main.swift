import Kitura
import SwiftRedis
import SwiftyJSON
import Foundation


// Create a new router
let router = Router()

struct MyVariablesGlobale { //Seulement local 
    static var nbkeys = [Int]()  //nombre de clé totale pour les messages postés
}

extension Int {
    var degreesToRadians: Double { return Double(self) * .pi / 180 }
    var radiansToDegrees: Double { return Double(self) * 180 / .pi }
}
extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}



// func JSONStringify(value: AnyObject, prettyPrinted: Bool = false) -> String {
//     var options = prettyPrinted ? NSJSONWritingOptions.PrettyPrinted : nil
//     if NSJSONSerialization.isValidJSONObject(value) {
//         if let data = NSJSONSerialization.dataWithJSONObject(value, options: options, error: nil) {
//             if let string = NSString(data: data, encoding: NSUTF8StringEncoding) {
//                 return string
//             }
//         }
//     }
//     return ""
// }

//faire le calcul pour la longitude/latitude  
    public func Distance(latitudeA_degre: String, longitudeA_degre: String, latitudeB_degre: String, longitudeB_degre: String) -> Float {

        //Convertir les données en float 
        //let latitudeA_deg_float = (latitudeA_degre as NSString).floatValue
        let latitudeA_deg_float = Float(latitudeA_degre)
        let longitudeA_deg_float = Float(longitudeA_degre)
        let latitudeB_deg_float = Float(latitudeB_degre)
        let longitudeB_deg_float = Float(longitudeB_degre)

        //Convertir les données de degrés en radian 
        let latitudeA = Float(latitudeA_deg_float!).degreesToRadians
        let longitudeA = Float(longitudeA_deg_float!).degreesToRadians
        let latitudeB = Float(latitudeB_deg_float!).degreesToRadians
        let longitudeB = Float(longitudeB_deg_float!).degreesToRadians

        var RayonTerre : Float
        RayonTerre = 63780000 //Rayon de la terre en mètre
        //var resultDistance: Float

        let distanceResult = RayonTerre * (3.14159265/2 - asin(sin(latitudeA) * sin(latitudeA) + cos(longitudeB - longitudeA) * cos(latitudeB) * cos(latitudeA)))

        return distanceResult
    }


// extension NSDate
// {
//     convenience
//       init(dateString:String) {
//       let dateStringFormatter = NSDateFormatter()
//       dateStringFormatter.dateFormat = "yyyy-MM-dd"
//       dateStringFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
//       let d = dateStringFormatter.dateFromString(dateString)!
//       self.init(timeInterval:0, sinceDate:d)
//     }
//  }

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
//  redis.connect(host: "", port: 6379)
//     request, response, next in
//     response.send("Hello, World!")
//     next()
// }

// router.get("/app/:name") { request, response, _ in
//     let name = request.parameters["name"] ?? ""
//     try response.send("Hello \(name)").end()
// }

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

router.get("/app/message") { request, response, next in //Renvoyer les informations au client android
    guard let parsedBody = request.body else {
        next()
        return 
    //{"longitude": "132.12", "latitude": "50.56", "radius": "35.24", "date": "12/11/17", "hours": "16.05"}
    }
    var longitudeMobile = ""
    var latitudeMobile = ""
    var radiusMobile = ""
    var dateMobile = ""
    var hoursMobile = ""

    switch(parsedBody) {
    case .json(let jsonBody):
            longitudeMobile = jsonBody["longitude"].string ?? ""
            latitudeMobile = jsonBody["latitude"].string ?? ""
            radiusMobile = jsonBody["radius"].string ?? ""
            dateMobile = jsonBody["date"].string ?? ""
            hoursMobile = jsonBody["hours"].string ?? ""

    default:
        break
    }
    //Recupérer tous les messages via la BDD
    //Selon le nombre de clés on fait une boucle pour récupérer tous les messages 
    var jsonResponse = JSON([:])
    //for nbkeys = 1; nbkeys <= 50; ++nbkeys {
    for i in stride(from: 0, to: 50, by: 1){
        redis.hgetall(String(i)) {(responseRedis:[String: RedisString], redisError: NSError?) in
            if let error = redisError {
                response.send("Error")
            }

            let valueLongitude = ""
            let valueLatitude = ""
            let valuePopularity = ""
            let valueDate = ""
            let valueHours = ""
            let valueTopic = ""
            var json = JSON([:])
            var jsonGlobal = JSON([:])
            
            //Recuperer les resultats
            switch(responseRedis) {
            case .Array(let responses):
                for idx in stride(from: 0, to: responses.count-1, by: 12) {
                    switch(responses[idx]) {
                        case .StringValue(let longitude):
                        
                            responses[idx+1].StringValue(valueLongitude)
                            json["longitude"].StringValue = valueLongitude
                            
                        case .StringValue(let latitude):
                        
                            responses[idx+1].StringValue(valueLatitude)
                            json["latitude"].StringValue = valueLatitude
                               
                        case .StringValue(let popularity):

                            responses[idx+1].StringValue(valuePopularity)
                            json["popularity"].StringValue = valuePopularity
                                
                        case .StringValue(let date):

                            responses[idx+1].StringValue(valueDate)
                            json["date"].StringValue = valueDate
                                
                        case .StringValue(let hours):

                            responses[idx+1].StringValue(valueHours)
                            json["hours"].StringValue = valueHours
                                        
                        case .StringValue(let topic):

                            responses[idx+1].StringValue(valueTopic)
                            json["topic"].StringValue = valueTopic
                                        
                        case .Error(let err):
                            error = self.createError("Error: \(err)", code: 1)
                        default:
                            error = self.createUnexpectedResponseError(response)
                    }
                }
                let radiusFloat = Float(radiusMobile) //Convertir le radius de string -> float valeur unité KM
                //Récupérer les éléments de chaque message en json 
                var resultDistance: Float

                let valueLat = json["latitude"].string
                let valueLongt = json["longitude"].string

                resultDistance = Distance(latitudeA_degre: latitudeMobile, longitudeA_degre: longitudeMobile, latitudeB_degre: valueLat!, longitudeB_degre: valueLongt!) //Appel de la fonction distance
                if resultDistance < radiusFloat! / 1000 {  //Comparaison de la distance entre les deux points et le radius


                }

                    // let jsonObject: [AnyObject] = [
                    //     ["name": "John", "age": 21],
                    //     ["name": "Bob", "age": 35],
                    

                    //jsonGlobal.append(json) 
                    //jsonGlobal["\(i)"].append(json) 
            

            default:
                break    
            }
        }
    }
    
    //Renvoyer le jsonGlobal au client

    jsonResponse["code"].stringValue = "400"
    jsonResponse["message"].stringValue = "Error"

    jsonResponse["code"].stringValue = "200"
    jsonResponse["message"].stringValue = "OK"
      

}
    

router.post("/app/message") { request, response, next in //Le mobile android poste un nouveau message
    guard let parsedBody = request.body else {
        next()
        return
    }
    var jsonResponse = JSON([:])
    //Recuperer le nombre de clé disponible dans la BDD
    var keys = 0
    redis.exists(String(keys)) {( nb: Int? , redisError: NSError?) in
        if let error = redisError {
            jsonResponse["code"].stringValue = "400"
            jsonResponse["message"].stringValue = "Error : \(error)" 
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
        //redis.hmset(newKey, fieldValuePairs: ("longitude", longit), ("latitude", latit), ("popularity", pop), ("date", d), ("hours", h), ("topic", top)) {(result: Bool?,redisError: NSError?) in
        redis.hmset(String(newKey), fieldValuePairs: ("longitude", longit), ("latitude", latit), ("popularity", pop), ("date", d), ("hours", h), ("topic", top)) {(result: Bool?, redisError: NSError?) in
            if let error = redisError {
                jsonResponse["code"].stringValue = "400"
                jsonResponse["message"].stringValue = "Error : \(error)"
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

    var jsonResponse = JSON([:])
    switch(parsedBody) {
    case .json(let jsonBody):
        let idMessage = jsonBody["key"].string ?? "" //Recupérer la valeur de l'id du topic
         redis.hincr(idMessage, field: "popularity", by: 1) {(value: Int?, redisError: NSError?) in//Incrémenter la valeur de la pop en fonction de l'ID du topic
            //Faire un hget pour voir la popularité de la clé 
            //Faire un hset pour incrémenter la popularité de la clé 
            if let error = redisError {
                jsonResponse["code"].stringValue = "400"
                jsonResponse["message"].stringValue = "Key Erreur : \(error)" 
            }
            else {
                jsonResponse["code"].stringValue = "200"
                jsonResponse["message"].stringValue = "popularity OK"
            }
        }
    default:
        break
    }
}   



// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8090, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()
