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


public class Controller {

  let router: Router
  let appEnv: AppEnv

  let authenticate = false

  let Auth_port = 6379 as Int32
  let Auth_host = "localhost"
  let Auth_password = "password"

  // let Auth_port = 15544 as Int32
  // let Auth_host = "sl-eu-lon-2-portal.2.dblayer.com"
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

  func Distance(latitudeA_degre: String, longitudeA_degre: String, latitudeB_degre: String, longitudeB_degre: String) -> Float {

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
    // var dateMobile = ""
    // var hoursMobile = ""

    switch(parsedBody) {
    case .json(let jsonBody):
      longitudeMobile = jsonBody["longitude"].string ?? ""
      latitudeMobile = jsonBody["latitude"].string ?? ""
      radiusMobile = jsonBody["radius"].string ?? ""
      // dateMobile = jsonBody["date"].string ?? ""
      // hoursMobile = jsonBody["hours"].string ?? ""

    default:
      break
    }

    print("longitudeMobile \(longitudeMobile)")
    var jsonResponse = JSON([:])

    let redis = Redis()
    connectRedis(redis: redis) { (redisError: NSError?) in
      if let error = redisError {
        jsonResponse["code"].stringValue = "500"
        jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
      }
      else{
        //On récupère les 50 dernière messages
        var j = 0
        for i in stride(from: 0,to: 50, by: 1){
          redis.hgetall(String(i)) {(responseRedis:[String: RedisString], redisError: NSError?) in
            if let error = redisError {        
              jsonResponse["code"].stringValue = "500"
              jsonResponse["message"].stringValue = "Erreur cmd redis hgetall: \(error)"
            }
            else if nil != responseRedis{
              //print("responseRedis 0 : \(responseRedis["date"]))")
              jsonResponse["code"].stringValue = "200"

              var json = JSON([:])
              var err = false
              json["id"].stringValue = String(i)

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
                print("message valide \(i) ")
                jsonResponse[String(j)] = json
                j += 1
              }
            }
          }
        }
        
      }
    }

    print("POST - /messages ")
    //Log.debug("POST - /sigup \(jsonResponse.rawString)")
    try response.status(.OK).send(json: jsonResponse).end()
  }

  public func postMessage(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("POST - /app/messages route handler...")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    
    guard let parsedBody = request.body else {
      next()
      return
    }

    var jsonResponse = JSON([:])
    
    jsonResponse["code"].stringValue = "200"
    jsonResponse["message"].stringValue = "message enregistré"

    print("POST - /app/message \(jsonResponse.rawString)")
    //Log.debug("POST - /sigup \(jsonResponse.rawString)")
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
              var newVal = (v.asInteger + 1)
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
    default:
      jsonResponse["code"].stringValue = "404"
      jsonResponse["message"].stringValue = "key required"
      break
    }
    
    

    print("POST - /app/mess/key \(jsonResponse.rawString)")
    //Log.debug("POST - /sigup \(jsonResponse.rawString)")
    try response.status(.OK).send(json: jsonResponse).end()
  }
}