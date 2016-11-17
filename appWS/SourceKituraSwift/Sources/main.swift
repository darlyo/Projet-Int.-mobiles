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
        RayonTerre = 6378 //Radius of earth in meters
 
        let distanceResult = RayonTerre * ((3.14159265/2) - asin(sin(latitudeB) * sin(latitudeA) + cos(longitudeB - longitudeA) * cos(latitudeB) * cos(latitudeA)))

        return distanceResult
    }


/////Connect to BDD Redis
let redis = Redis()

func connectRedis (redis : Redis, callback: (NSError?) -> Void) { //Fonction connexion vers la BDD redis 
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


router.post("/app/messages") { request, response, next in //Send messages by distance and hours 
    guard let parsedBody = request.body else {
        next()
        return 
    }
    var longitudeMobile = ""
    var latitudeMobile = ""
    var radiusMobile = ""
    var dateMobile = ""
    var hoursMobile = ""
    var token = "" //ID pour acceptation de l'authentification

    switch(parsedBody) {
    case .json(let jsonBody):
            longitudeMobile = jsonBody["longitude"].string ?? ""
            latitudeMobile = jsonBody["latitude"].string ?? ""
            radiusMobile = jsonBody["radius"].string ?? ""
            dateMobile = jsonBody["date"].string ?? ""
            hoursMobile = jsonBody["hours"].string ?? ""
            tokenMobile = jsonBody["token"].string ?? ""

    default:
        break
    }//fin switch
    
    //Appel au service web auth 
    //A faire requête 


    var jsonResponse = JSON([:])

    let redis = Redis()
    connectRedis(redis: redis) { (redisError: NSError?) in
        if let error = redisError {
            jsonResponse["code"].stringValue = "500"
            jsonResponse["message"].stringValue = "Error connect redis: \(error)"
        }
        else 
        {
            var maxMsg = 50 //Valeur par défaut 
            var fromMsg = 1 //Valeur par défaut
            
            redis.get("nb") { (value: RedisString?, redisError: NSError?) in //Récupérer le nombre de messages dans la BDD

                if let error = redisError {
                    jsonResponse["code"].stringValue = "500"
                    jsonResponse["message"].stringValue = "Error cmd redis get nb: \(error)"
                }
                
                if let nb = value{
                    maxMsg = nb.asInteger //nombre max de messages
                    fromMsg = maxMsg - 50 //Récupération des 50 derniers messages enregistrés dans la BDD 
                    if fromMsg < 1{
                      fromMsg = 1
                    }
                }
            }
            print("find of \(fromMsg) to \(maxMsg)")

            var j = 0 //indice du num de message dans la chaine json globale
            for i in stride(from: fromMsg,to: maxMsg, by: 1){
                
                redis.hgetall(String(i)) {(responseRedis:[String: RedisString], redisError: NSError?) in //Récupérer tous les messages via la BDD
                
                    if let error = redisError {        
                        jsonResponse["code"].stringValue = "500"
                        jsonResponse["message"].stringValue = "Error cmd redis hgetall: \(error)"
                    }
                    else 
                    {
                        jsonResponse["code"].stringValue = "200"

                        var json = JSON([:]) //Récupérer les éléments de chaque message dans une chaine json
                        var err = false
                        json["id"].stringValue = String(i) //On ajoute l'élément id avec sa valeur pour chaque message récupéré

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
                            let radiusFloat = Double(radiusMobile) //Convertir radius de string -> Double (unité km)
                             
                            var resultDistance: Double //Résultat de la fonction distance (unité km)

                            let valueLat = json["latitude"].string //Récupérer la valeur latitude du message courant 
                            let valueLongt = json["longitude"].string //Récupérer la valeur latitude du message courant

                            resultDistance = Distance(latitudeA_degre: latitudeMobile, longitudeA_degre: longitudeMobile, latitudeB_degre: valueLat!, longitudeB_degre: valueLongt!) //Appel de la fonction distance
                            if resultDistance <= radiusFloat! {  //Comparaison de la distance récupérée et le radius (distance demandé par client mobile)
                                print("message valide \(i) ")
                                jsonResponse[String(j)] = json //Ajouter le message dans la liste global (messages conformes)
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
    try response.status(.OK).send(json: jsonResponse).end() //Envoie du message au mobile android 
}

//////////////////////////////////////////////////////////////////////////////////////////

router.post("/app/message") { request, response, next in //Poster un nouveau message
    guard let parsedBody = request.body else {
        next()
        return
    }

    var jsonResponse = JSON([:]) //Message json à envoyer au client 

    switch(parsedBody) { //On parse le message recu avec les différents éléments du corps "parseBody"
    case .json(let jsonBody):
      let longitude = jsonBody["longitude"].string ?? ""
      let latitude = jsonBody["latitude"].string ?? ""
      let date = jsonBody["date"].string ?? ""
      let hours = jsonBody["hours"].string ?? ""
      let topic = jsonBody["topic"].string ?? ""
      let token = jsonBody["token"].string ?? ""


    //Appel au service web auth 
    //A faire requête


    let redis = Redis()
      connectRedis(redis: redis) { (redisError: NSError?) in
        if let error = redisError {
          jsonResponse["code"].stringValue = "500"
          jsonResponse["message"].stringValue = "Error connect redis: \(error)"
        }

        else {
          redis.incr("nb"){(value : Int?, redisError: NSError?) in //Incrémenter la valeur de la clé "nb"      
            if let error = redisError {
              jsonResponse["code"].stringValue = "500"
              jsonResponse["message"].stringValue = "Error redis cmd incr: \(error)"
            }
            else if let nb = value { //Si la nouvelle valeur est conforme. Appel fonction HMSET pour envoyer les infos du nouveau message vers la BDD
                
                redis.hmset(String(nb), fieldValuePairs: ("longitude",longitude),("latitude",latitude),("date",date),("hours",hours),("topic",topic),("popularity","0")) {(ok : Bool, redisError: NSError?) in 
                        
                    if let error = redisError { //Erreur de la BDD 
                        jsonResponse["code"].stringValue = "500"
                        jsonResponse["message"].stringValue = "Erreur redis cmd hmset: \(error)"
                    }
                    else { //Le message a été enregistré dans la BDD
                        jsonResponse["code"].stringValue = "200"
                        jsonResponse["message"].stringValue = "\(nb)"
                            
                        redis.pub("app/messages",value:"un publish"){(v : Int?, redisError: NSError?) in //On appelle la BDD pour avertir qu'un nouveau message à été créé 
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
            else {
                  jsonResponse["code"].stringValue = "500"
                  jsonResponse["message"].stringValue = "Error server"
                }   
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

router.post("app/mess/key") { request, response, next in //Incrémenter la popularité du message 
    guard let parsedBody = request.body else {
        next()
        return
    }

    var jsonResponse = JSON([:])
    switch(parsedBody) {
    case .json(let jsonBody):
    let idMessage = jsonBody["key"].string ?? "" //Recupérer la valeur de l'id du topic dans le corps du message 
    let token = jsonBody["token"].string ?? "" //Recuperer la valeur du token 

     //Appel au service web auth 
    //A faire requête

    
    let redis = Redis()
    connectRedis(redis: redis) { (redisError: NSError?) in //Connexion avec la BDD redis 
        if let error = redisError { //Si erreur de connexion 
          jsonResponse["code"].stringValue = "500"
          jsonResponse["message"].stringValue = "Error connect redis: \(error)"
        }

        else { //Si la connexion OK

            redis.hget(idMessage, field:"popularity") {(value: RedisString?, redisError: NSError?) in //Récupérer la valeur de la pop à partir de l'ID du message
                if let error = redisError {
                  jsonResponse["code"].stringValue = "400"
                  jsonResponse["message"].stringValue = "Error Key : \(error)"
                }

                if let v = value { //Si la valeur ID est reconnu par la BDD alors 
                  let  newVal = (v.asInteger + 1) //Incrémenter la valeur de la pop 
                  redis.hset(idMessage, field:"popularity", value: String(newVal)) {(ok: Bool?, redisError: NSError?) in //Envoyer la nouvelle pop vers la BDD
                    if let error = redisError {
                      jsonResponse["code"].stringValue = "400"
                      jsonResponse["message"].stringValue = "Error Key : \(error)"
                    }
                    else { //La nouvelle valeur à été modifiée 
                      jsonResponse["code"].stringValue = "200"
                      jsonResponse["message"].stringValue = "popularity OK"
                      jsonResponse["popularity"].stringValue = "\(newVal)"
                    }
                  }//fin request redis HSET 
                }
                else { 
                  jsonResponse["code"].stringValue = "400"
                  jsonResponse["message"].stringValue = "Incorrect key"
                }
            }//fin request redis HGET 
         
        }//Fin else
    }//Fin connect Resdis   
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
