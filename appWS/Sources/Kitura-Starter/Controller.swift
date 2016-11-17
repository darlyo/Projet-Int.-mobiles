/**
* Copyright IBM Corporation 2016
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
**/

import Kitura
import Foundation
import KituraRequest

import LoggerAPI
import HeliumLogger
import CloudFoundryEnv

import SwiftRedis
import SwiftyJSON

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif


extension Int {
    var degreesToRadians: Double { return Double(self) * .pi / 180 }
    var radiansToDegrees: Double { return Double(self) * 180 / .pi }
}
extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}

extension Redis {
  func redisIntegerResponseHandler(_ response: RedisResponse, callback: (Int?, NSError?) -> Void) {
    switch(response) {
    case .IntegerValue(let num):
        callback(Int(num), nil)
    case .Nil:
        callback(nil, nil)
    case .Error(let error):
        callback(nil, _: createError("Error: \(error)", code: 1))
    default:
        callback(nil, _: createUnexpectedResponseError(response))
    }
  }

  func createUnexpectedResponseError(_ response: RedisResponse) -> NSError {
    return createError("Unexpected result received from Redis \(response)", code: 2)
  }

  func createError(_ errorMessage: String, code: Int) -> NSError {
    #if os(Linux)
        let userInfo: [String: Any]
    #else
        let userInfo: [String: String]
    #endif
    userInfo = [NSLocalizedDescriptionKey: errorMessage]
    return NSError(domain: "RedisDomain", code: code, userInfo: userInfo)
  }

  public func pub(_ channel: String, value: String, callback: (Int?, NSError?) -> Void) {
      
    let command = ["PUBLISH", channel, value]
    issueCommandInArray(command) {(response: RedisResponse) in
      self.redisIntegerResponseHandler(response, callback: callback)
    }
  }
}


public class Controller {

  let router: Router
  let appEnv: AppEnv

  let authenticate = true

  let Auth_port = 15601 as Int32
  let Auth_host = "sl-eu-lon-2-portal.2.dblayer.com"
  let Auth_password = "ZLAQLGVSVAGEZDCX"

  // let Auth_port = 15544 as Int32
  // let Auth_host = "http://localhost"
  // let Auth_password = "LTWCJWJPVKKGMUGZ"

  var port: Int {
    get { return appEnv.port }
  }

  var url: String {
    get { return appEnv.url }
  }

  init() throws {

    appEnv = try CloudFoundryEnv.getAppEnv()

    // All web apps need a Router instance to define routes
    router = Router()

    // Serve static content from "public"
    router.all("/*", middleware: StaticFileServer())
    router.all("/*", middleware: BodyParser())

    // Connect user, POST request 
    router.post("/app/messages", handler: postMessages) //envoie les messages demander
    router.post("/app/message", handler: postMessage) // enregistre le message
    router.post("/app/mess/key", handler: postAugPop) // augmente la popularity d'un message


  }

  public func Distance(latitudeA_degre: String, longitudeA_degre: String, latitudeB_degre: String, longitudeB_degre: String) -> Double {

    //Convertir les données en float 
    //let latitudeA_deg_float = (latitudeA_degre as NSString).floatValue
    let latitudeA_deg_float = Double(latitudeA_degre)
    let longitudeA_deg_float = Double(longitudeA_degre)
    let latitudeB_deg_float = Double(latitudeB_degre)
    let longitudeB_deg_float = Double(longitudeB_degre)
    print("Distance convert in double")
    
    //Convertir les données de degrés en radian 
    let latitudeA = Double(latitudeA_deg_float!).degreesToRadians
    let longitudeA = Double(longitudeA_deg_float!).degreesToRadians
    let latitudeB = Double(latitudeB_deg_float!).degreesToRadians
    let longitudeB = Double(longitudeB_deg_float!).degreesToRadians
    print("Distance convert in Radian")

    var RayonTerre : Double
    RayonTerre = 6378 
    //var resultDistance: Float

    let distanceResult = RayonTerre * ((3.14159265/2) - asin(sin(latitudeB) * sin(latitudeA) + cos(longitudeB - longitudeA) * cos(latitudeB) * cos(latitudeA)))

    print("Distance entre A(\(longitudeA);\(latitudeA)) et B(\(longitudeB);\(latitudeB)) : \(distanceResult)")
    return distanceResult
  }

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

  func checkToken(token : String) -> Bool {
    var ok = false
    KituraRequest.request(.get, "http://localhost:8090/check/\(token)").response {
      request, response, data, error in
      if let d = data {
        let s1 = String(data: data!, encoding: String.Encoding.ascii)!
        let json = JSON(data: data!)
        let v = json["code"].stringValue
        if v == "200"{
          ok = true
        } 
      }
    }
    print("checkToken : \(ok)")
    return ok
  }

  public func postMessages(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("POST - /app/messages route handler...")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    
    guard let parsedBody = request.body else {
      next()
      return
    }

    var longitudeMobile = ""
    var latitudeMobile = ""
    var radiusMobile = ""
    var token = ""
    // var dateMobile = ""
    // var hoursMobile = ""

    switch(parsedBody) {
    case .json(let jsonBody):
      longitudeMobile = jsonBody["longitude"].string ?? "0"
      latitudeMobile = jsonBody["latitude"].string ?? "0"
      radiusMobile = jsonBody["radius"].string ?? "99999"
      token = jsonBody["token"].string ?? "0"
      // dateMobile = jsonBody["date"].string ?? ""
      // hoursMobile = jsonBody["hours"].string ?? ""

    default:
      break
    }

    var jsonResponse = JSON([:])
    if checkToken(token : token) {
      let redis = Redis()
      connectRedis(redis: redis) { (redisError: NSError?) in
        if let error = redisError {
          jsonResponse["code"].stringValue = "500"
          jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
        }
        else{

          var maxMsg = 100
          var fromMsg = 1
          redis.get("nb") { (value: RedisString?, redisError: NSError?) in

            if let error = redisError {
              jsonResponse["code"].stringValue = "500"
              jsonResponse["message"].stringValue = "Erreur cmd redis get nb: \(error)"
            }
            if let nb = value{
              maxMsg = nb.asInteger
              fromMsg = maxMsg - 100
              if fromMsg < 1{
                fromMsg = 1
              }
            }
          }        
          print("rechcher de \(fromMsg) to \(maxMsg)")
          //On récupère les 50 dernière messages
          var j = 0

          for i in stride(from: fromMsg,to: maxMsg+1, by: 1){
            redis.hgetall(String(i)) {(responseRedis:[String: RedisString], redisError: NSError?) in
              if let error = redisError {        
                jsonResponse["code"].stringValue = "500"
                jsonResponse["message"].stringValue = "Erreur cmd redis hgetall: \(error)"
              }
              else {
                //print("responseRedis 0 : \(responseRedis["date"]))")
                jsonResponse["code"].stringValue = "200"

                var json = JSON([:])
                var err = false
                json["id"].stringValue = String(i)
                print("responseRedis \(i) : \(responseRedis["date"]))")

                if let val = responseRedis["longitude"]{
                  json["longitude"].stringValue = val.asString
                }else {
                  err = true
                }
                if let val = responseRedis["latitude"]{
                  json["latitude"].stringValue = val.asString
                }else {
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

                //write in JSON the message if valide
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
              }
            }
          } 
        }
      }
    }
    else{
      jsonResponse["code"].stringValue = "500"
      jsonResponse["message"].stringValue = "token incorrect"
    }
    print("POST - /app/messages ")
    Log.debug("POST - /app/messages \(jsonResponse.rawString)")
    try response.status(.OK).send(json: jsonResponse).end()
  }

  public func postMessage(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("POST - /app/message route handler...")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    
    guard let parsedBody = request.body else {
      next()
      return
    }

    var jsonResponse = JSON([:])

    switch(parsedBody) {
    case .json(let jsonBody):
      let longitude = jsonBody["longitude"].string ?? "0"
      let latitude = jsonBody["latitude"].string ?? "0"
      let date = jsonBody["date"].string ?? "1/1/2000"
      let hours = jsonBody["hours"].string ?? "00:00"
      let topic = jsonBody["topic"].string ?? ""
      let token = jsonBody["token"].string ?? "0"

      // check token
      if checkToken(token:token) {
        let redis = Redis()
        connectRedis(redis: redis) { (redisError: NSError?) in
          if let error = redisError {
            jsonResponse["code"].stringValue = "500"
            jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
          }

          else{
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
                    // let pub = "{\"contenu\": \"ceci est un test", "date_post": "8/11/2016", "latitude": "30.0", "longitude": "30.0"}'
                    let pub = "{\"contenu\": \"\(topic)\", \"date_post\": \"\(date)\", \"latitude\": \"\(latitude)\", \"longitude\": \"\(longitude)\"}"
                    
                    redis.pub("App_BD",value:pub){(v : Int?, redisError: NSError?) in
                      if let error = redisError {
                        print("erreur publish \(error)")
                      }
                      else {
                        print("publish ok")
                      }
                    }
                  }
                }
              }
            }
            
          }
        }
      }
      else{
        jsonResponse["code"].stringValue = "500"
        jsonResponse["message"].stringValue = "token incorrect"
      }
    default:
      jsonResponse["code"].stringValue = "400"
      jsonResponse["message"].stringValue = "JSON required"
      break
    }

    print("POST - /app/message \(jsonResponse.rawString)")
    Log.debug("POST - /app/message \(jsonResponse.rawString)")
    try response.status(.OK).send(json: jsonResponse).end()
  }

  public func postAugPop(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("POST - /app/mess/key route handler...")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    
    guard let parsedBody = request.body else {
      next()
      return
    }

    var jsonResponse = JSON([:])
    switch(parsedBody) {
    case .json(let jsonBody):
      let idMessage = jsonBody["key"].string ?? "" //Recupérer la valeur de l'id du topic
      let token = jsonBody["token"].string ?? "" //Recupérer la valeur de l'id du topic

      let valide = checkToken(token : token)
      if valide{
        let redis = Redis()
        connectRedis(redis: redis) { (redisError: NSError?) in
          if let error = redisError {
            jsonResponse["code"].stringValue = "500"
            jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
          }

          else {
            redis.hget(idMessage, field:"popularity") {(value: RedisString?, redisError: NSError?) in
              if let error = redisError {
                jsonResponse["code"].stringValue = "500"
                jsonResponse["message"].stringValue = "Key Erreur : \(error)"
              }

              if let v = value {
                let  newVal = (v.asInteger + 1)
                redis.hset(idMessage, field:"popularity", value: String(newVal)) {(ok: Bool?, redisError: NSError?) in
                  if let error = redisError {
                    jsonResponse["code"].stringValue = "500"
                    jsonResponse["message"].stringValue = "Key Erreur : \(error)"
                  }
                  else {
                    jsonResponse["code"].stringValue = "200"
                    jsonResponse["message"].stringValue = "popularity OK"
                    jsonResponse["popularity"].stringValue = "\(newVal)"
                  }
                }
              }
              else {
                jsonResponse["code"].stringValue = "500"
                jsonResponse["message"].stringValue = "Key incorrect"
              }
            }
          }
        }
      }
      else{
        jsonResponse["code"].stringValue = "500"
        jsonResponse["message"].stringValue = "token incorrect"
      }
    default:
      jsonResponse["code"].stringValue = "404"
      jsonResponse["message"].stringValue = "key required"
      break
    }
    
    print("POST - /app/mess/key \(jsonResponse.rawString)")
    Log.debug("POST - /pp/mess/key \(jsonResponse.rawString)")
    try response.status(.OK).send(json: jsonResponse).end()
  }
}
