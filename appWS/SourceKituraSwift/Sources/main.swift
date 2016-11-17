import Kitura
import SwiftRedis
import SwiftyJSON
import Foundation
import LoggerAPI
import HeliumLogger


// Create a new router
let router = Router()
Log.logger = HeliumLogger()
router.all("/", middleware: BodyParser())
let Auth_port = 6379 as Int32
let Auth_host = "localhost"
let Auth_password = "password"
let authenticate = false

struct MyVariablesGlobale { //Only local
    static var nbkeys = [Int]()  //Number of total keys 
}

extension Int {
    var degreesToRadians: Double { return Double(self) * .pi / 180 }
    var radiansToDegrees: Double { return Double(self) * 180 / .pi }
}
extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}


    //Function to calculate the distance between 2 points
    public func Distance(latitudeA_degre: String, longitudeA_degre: String, latitudeB_degre: String, longitudeB_degre: String) -> Double {

        //Convert data from String to Double
        let latitudeA_deg_float = Double(latitudeA_degre)
        let longitudeA_deg_float = Double(longitudeA_degre)
        let latitudeB_deg_float = Double(latitudeB_degre)
        let longitudeB_deg_float = Double(longitudeB_degre)

        //Convert data from degrees to radian 
        let latitudeA = Double(latitudeA_deg_float!).degreesToRadians
        let longitudeA = Double(longitudeA_deg_float!).degreesToRadians
        let latitudeB = Double(latitudeB_deg_float!).degreesToRadians
        let longitudeB = Double(longitudeB_deg_float!).degreesToRadians

        var RayonTerre : Double
        RayonTerre = 63780000 //Radius of earth in meters
 
        let distanceResult = RayonTerre * ((3.14159265/2) - asin(sin(latitudeB) * sin(latitudeA) + cos(longitudeB - longitudeA) * cos(latitudeB) * cos(latitudeA)))

        return distanceResult/10000
    }


/////Connect to BDD Redis
let redis = Redis()

func connectRedis (redis : Redis, callback: (NSError?) -> Void) {
    if !redis.connected {

        redis.connect(host: Auth_host, port: Auth_port) {(error: NSError?) in
            if authenticate {
                redis.auth(Auth_password, callback: callback)
            } else {
                callback(error)
            }
        }
    } else {
        callback(nil)
    }
  }


router.post("/app/messages") { request, response, next in //Send messages to android
    guard let parsedBody = request.body else {
        next()
        return 
    //{"longitude": "132.12", "latitude": "50.56", "radius": "35.24", "date": "12/11/17", "hours": "16.05"}
    }
    var longitudeMobile = ""
    var latitudeMobile = ""
    var radiusMobile = ""
    //var dateMobile = ""
    var hoursMobile = ""

    switch(parsedBody) {
    case .json(let jsonBody):
            longitudeMobile = jsonBody["longitude"].string ?? ""
            latitudeMobile = jsonBody["latitude"].string ?? ""
            radiusMobile = jsonBody["radius"].string ?? ""
            //dateMobile = jsonBody["date"].string ?? ""
            hoursMobile = jsonBody["hours"].string ?? ""

    default:
        break
    }//fin switch
    //Recupérer tous les messages via la BDD
    //Selon le nombre de clés on fait une boucle pour récupérer tous les messages 

    var jsonResponse = JSON([:])

    let redis = Redis()
    connectRedis(redis: redis) { (redisError: NSError?) in
        if let error = redisError {
            jsonResponse["code"].stringValue = "500"
            jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
        }
        else 
        {
            var maxMsg = 50
            var fromMsg = 1
            
            redis.get("nb") { (value: RedisString?, redisError: NSError?) in

                if let error = redisError {
                    jsonResponse["code"].stringValue = "500"
                    jsonResponse["message"].stringValue = "Erreur cmd redis get nb: \(error)"
                }
                
                if let nb = value{
                    maxMsg = nb.asInteger
                    fromMsg = maxMsg - 50
                    if fromMsg < 1{
                      fromMsg = 1
                    }
                }
            }
            print("find of \(fromMsg) to \(maxMsg)")
            
            //On récupère les 50 dernière messages
            var j = 0
            for i in stride(from: 1,to: 50, by: 1){
                
                redis.hgetall(String(i)) {(responseRedis:[String: RedisString], redisError: NSError?) in
                
                    if let error = redisError {        
                        jsonResponse["code"].stringValue = "500"
                        jsonResponse["message"].stringValue = "Erreur cmd redis hgetall: \(error)"
                    }
                    else 
                    {

                        jsonResponse["code"].stringValue = "200"

                        var json = JSON([:])
                        var err = false
                        json["id"].stringValue = String(i)

                        if let val = responseRedis["longitude"]{
                            json["longitude"].stringValue = val.asString
                        }
                        else {
                            err = true
                        }
                        if let val = responseRedis["latitude"]{
                            json["latitude"].stringValue = val.asString
                        }
                        else {
                            err = true
                        }
                        if let val = responseRedis["popularity"]{
                            json["popularity"].stringValue = val.asString
                        }else {
                            err = true
                        }
                        if let val = responseRedis["date"]{
                            json["date"].stringValue = val.asString
                        }else {
                            err = true
                        }
                        if let val = responseRedis["hours"]{
                            json["hours"].stringValue = val.asString
                        }else {
                            err = true
                        }
                        if let val = responseRedis["topic"]{
                            json["topic"].stringValue = val.asString
                        }else {
                            err = true
                        }        

                        if err == false {
                            let radiusFloat = Double(radiusMobile) //Convertir le radius de string -> float valeur unité KM
                            //Récupérer les éléments de chaque message en json 
                            var resultDistance: Double

                            let valueLat = json["latitude"].string
                            let valueLongt = json["longitude"].string

                            resultDistance = Distance(latitudeA_degre: latitudeMobile, longitudeA_degre: longitudeMobile, latitudeB_degre: valueLat!, longitudeB_degre: valueLongt!) //Appel de la fonction distance
                            if resultDistance <= radiusFloat! {  //Comparaison de la distance entre les deux points et le radius
                                print("message valide \(i) ")
                                jsonResponse[String(j)] = json
                                j += 1
                            }
                        }
                    }//fin else
                }//fin redis hgetall
            }//fin for
        }//fin else
    }//fin connect redis 
    print("POST - /messages ")
    //Log.debug("POST - /sigup \(jsonResponse.rawString)")
    try response.status(.OK).send(json: jsonResponse).end()
}

//////////////////////////////////////////////////////////////////////////////////////////

router.post("/app/message") { request, response, next in //Le mobile android poste un nouveau message
    guard let parsedBody = request.body else {
        next()
        return
    }

    var jsonResponse = JSON([:])

    switch(parsedBody) {
    case .json(let jsonBody):
      let longitude = jsonBody["longitude"].string ?? ""
      let latitude = jsonBody["latitude"].string ?? ""
      let date = jsonBody["date"].string ?? ""
      let hours = jsonBody["hours"].string ?? ""
      let topic = jsonBody["topic"].string ?? ""


    let redis = Redis()
      connectRedis(redis: redis) { (redisError: NSError?) in
        if let error = redisError {
          jsonResponse["code"].stringValue = "500"
          jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
        }

        else {
          redis.incr("nb"){(value : Int?, redisError: NSError?) in
            if let error = redisError {
              jsonResponse["code"].stringValue = "500"
              jsonResponse["message"].stringValue = "Erreur redis cmd incr: \(error)"
            }
            else if let nb = value {
                
                redis.hmset(String(nb), fieldValuePairs: ("longitude",longitude),("latitude",latitude),("date",date),("hours",hours),("topic",topic),("popularity","0")) {(ok : Bool, redisError: NSError?) in 
                        
                if let error = redisError {
                    jsonResponse["code"].stringValue = "500"
                    jsonResponse["message"].stringValue = "Erreur redis cmd hmset: \(error)"
                }
                else {
                    jsonResponse["code"].stringValue = "200"
                    jsonResponse["message"].stringValue = "\(nb)"
                        
                    redis.pub("app/messages",value:"un publish"){(v : Int?, redisError: NSError?) in
                        if let error = redisError {
                            print("erreur publish \(error)")
                        }
                        else {
                            
                            print("publish ok")
                        }
                    }//fin redis publish
                }//Fin else
                }//Fin redis Hmset
            }//fin else if   
          }//fin redis incr
          
        }//fin else
      }//Fin redis connect  
      default:
      jsonResponse["code"].stringValue = "400"
      jsonResponse["message"].stringValue = "JSON required"
      break
    }//fin switch

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
    
    let redis = Redis()
    connectRedis(redis: redis) { (redisError: NSError?) in
        if let error = redisError {
          jsonResponse["code"].stringValue = "500"
          jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
        }

        else {

            redis.hget(idMessage, field:"popularity") {(value: RedisString?, redisError: NSError?) in
                if let error = redisError {
                  jsonResponse["code"].stringValue = "400"
                  jsonResponse["message"].stringValue = "Key Erreur : \(error)"
                }

                if let v = value {
                  let  newVal = (v.asInteger + 1)
                  redis.hset(idMessage, field:"popularity", value: String(newVal)) {(ok: Bool?, redisError: NSError?) in
                    if let error = redisError {
                      jsonResponse["code"].stringValue = "400"
                      jsonResponse["message"].stringValue = "Key Erreur : \(error)"
                    }
                    else {
                      jsonResponse["code"].stringValue = "200"
                      jsonResponse["message"].stringValue = "popularity OK"
                      jsonResponse["popularity"].stringValue = "\(newVal)"
                    }
                  }//fin request redis HSET 
                }
                else {
                  jsonResponse["code"].stringValue = "400"
                  jsonResponse["message"].stringValue = "Key incorrect"
                }
            }//fin request redis HGET 
         
        }//Fin else
    }//FIn connect Resdis   
    default:
      jsonResponse["code"].stringValue = "404"
      jsonResponse["message"].stringValue = "key required"
      break
    }//Fin switch
    
    print("POST - /app/mess/key \(jsonResponse.rawString)")
    try response.status(.OK).send(json: jsonResponse).end()
  }



// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8090, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()
