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

  let Auth_port = 6379 as Int32
  let Auth_host = "localhost"
  let Auth_password = "password"

  let authenticate = false

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

  public func checkToken(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("GET - /check/:token route handler...")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"

    let token = request.parameters["token"] ?? ""
    
    var jsonResponse = JSON([:])


    // Start framework redisError
    let redis = Redis()
    // Connect in local
    connectRedis(redis: redis) { (redisError: NSError?) in
      if let error = redisError {
        jsonResponse["code"].stringValue = "500"
        jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"

        //response.send("error")
      }

      else {
        print("Connected to Redis")
        // set a key
        redis.ttl(token) { (time: TimeInterval?, redisError: NSError?) in
          if let error = redisError {
            jsonResponse["code"].stringValue = "500"
            jsonResponse["message"].stringValue = "Erreur cmd redis ttl: \(error)"                
          }
          else if time! == -1 {
            jsonResponse["code"].stringValue = "500"
            jsonResponse["message"].stringValue = "token invalide, time expire"
            //response.send("token invalide, time expire")
          }
          else if time! == -2 {
            jsonResponse["code"].stringValue = "500"
            jsonResponse["message"].stringValue = "token inconnu"
            //response.send("token : \(token) invalide")
          }
          else{
            jsonResponse["code"].stringValue = "200"
            jsonResponse["message"].stringValue = "valide"
            //response..status(.OK).send("Check OK, token valide, time remaning : \(time)")
          }
        }
      }
    }
    try response.status(.OK).send(json: jsonResponse).end()
  }

  public func postConnect(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("POST - /connect route handler...")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    
    guard let parsedBody = request.body else {
      next()
      return
    }

    var jsonResponse = JSON([:])
    switch(parsedBody) {
    case .json(let jsonBody):
      let user = jsonBody["user"].string ?? ""
      let password = jsonBody["password"].string ?? ""

      let redis = Redis()
      connectRedis(redis: redis) { (redisError: NSError?) in

        if let error = redisError {
          jsonResponse["code"].stringValue = "500"
          jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
        }

        else
        {
          redis.get(user) { (pass: RedisString?, redisError: NSError?) in

            if let error = redisError {
              jsonResponse["code"].stringValue = "500"
              jsonResponse["message"].stringValue = "Erreur cmd redis get \(user): \(error)"
            }
            else if let mdp = pass {
              if mdp.asString == password {
                let rand = random()
                redis.set(String(rand),value: user,exists: false,expiresIn: (60000 as TimeInterval)){ (ok: Bool?, redisError: NSError?) in
                  if let error = redisError {
                    jsonResponse["code"].stringValue = "500"
                    jsonResponse["message"].stringValue = "Erreur cmd redis set token: \(error)"              
                  }
                  else {
                    jsonResponse["code"].stringValue = "200"
                    jsonResponse["message"].stringValue = "\(rand)"              
                  }
                }
              }
              else {
                jsonResponse["code"].stringValue = "500"
                jsonResponse["message"].stringValue = "Invalide password"
              }
            }
            else {
              jsonResponse["code"].stringValue = "500"
              jsonResponse["message"].stringValue = "Invalide user"
            }
          }
        }
      }
    default:
      break
    }
    print("POST - /connect \(jsonResponse["message"].stringValue)")
    Log.debug("POST - /connect \(jsonResponse["message"].stringValue)")
    try response.status(.OK).send(json: jsonResponse).end()
  }

  public func postDisconnect(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("POST - /disconnect route handler...")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"

    guard let parsedBody = request.body else {
      next()
      return
    }

    var jsonResponse = JSON([:])

    switch(parsedBody) {
    case .json(let jsonBody):

      let user_redis = jsonBody["user"].string ?? ""
      let token = jsonBody["token"].string ?? ""

      let redis = Redis()
      connectRedis(redis: redis) { (redisError: NSError?) in

        if let error = redisError {
          jsonResponse["code"].stringValue = "500"
          jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
        }

        else
        {
          redis.get(token) { (u: RedisString?, redisError: NSError?) in

            if let error = redisError {
              jsonResponse["code"].stringValue = "500"
              jsonResponse["message"].stringValue = "Erreur cmd redis get \(user_redis): \(error)"
            }

            else if let user = u {
              if user.asString == user_redis {

                redis.expire(token,inTime: (1 as TimeInterval)) { (ok: Bool?, redisError: NSError?) in
                  if let error = redisError {
                    jsonResponse["code"].stringValue = "500"
                    jsonResponse["message"].stringValue = "Erreur cmd redis expire : \(error)"              
                  }
                  else {
                    jsonResponse["code"].stringValue = "200"
                    jsonResponse["message"].stringValue = "disconnect"              
                  }
                }
              }
              else {
                jsonResponse["code"].stringValue = "500"
                jsonResponse["message"].stringValue = "Invalide user"
              }
            }
            else {
              jsonResponse["code"].stringValue = "500"
              jsonResponse["message"].stringValue = "Invalide token"
            }
          }
        }
      }
    default:
      break
    }
    print("POST - /disconnect \(jsonResponse["message"].stringValue)")
    Log.debug("POST - /disconnect \(jsonResponse["message"].stringValue)")
    try response.status(.OK).send(json: jsonResponse).end()
  }

  public func postSignUp(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("POST - /signup route handler...")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    
    guard let parsedBody = request.body else {
      next()
      return
    }

    var jsonResponse = JSON([:])

    switch(parsedBody) {
    case .json(let jsonBody):

      let user = jsonBody["user"].string ?? ""
      let password = jsonBody["password"].string ?? ""

      let redis = Redis()
      connectRedis(redis: redis) { (redisError: NSError?) in

        if let error = redisError {
          jsonResponse["code"].stringValue = "500"
          jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
        }

        else
        {
          redis.set(user, value:password,exists:false) { (ok: Bool?, redisError: NSError?) in

            if let error = redisError {
              jsonResponse["code"].stringValue = "500"
              jsonResponse["message"].stringValue = "Erreur cmd redis set \(user): \(error)"
            }
            else if ok == true {                
                jsonResponse["code"].stringValue = "200"
                jsonResponse["message"].stringValue = "user create"              
            }
            else {
              jsonResponse["code"].stringValue = "500"
              jsonResponse["message"].stringValue = "user already exist"              
            }
          }
        }
      }
    default:
      break
    }
    print("POST - /sigup \(jsonResponse["message"].stringValue)")
    Log.debug("POST - /sigup \(jsonResponse["message"].stringValue)")
    try response.status(.OK).send(json: jsonResponse).end()
  }

  public func postMessages(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("POST - /app/messages route handler...")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    
    guard let parsedBody = request.body else {
      next()
      return
    }

    var jsonResponse = JSON([:])
    
    jsonResponse["code"].stringValue = "200"

    var json = JSON([:])
    json["id"].stringValue = "10"
    json["longitude"].stringValue = "10"
    json["latitude"].stringValue = "10"
    json["popularity"].stringValue = "10"
    json["date"].stringValue = "10"
    json["hours"].stringValue = "10"
    json["topic"].stringValue = "10"


    jsonResponse["1"] = json

    print("POST - /sigup \(jsonResponse.rawString)")
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

    print("POST - /sigup \(jsonResponse.rawString)")
    //Log.debug("POST - /sigup \(jsonResponse.rawString)")
    try response.status(.OK).send(json: jsonResponse).end()
  }

  public func postAugPop(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("POST - /app/messages route handler...")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    
    guard let parsedBody = request.body else {
      next()
      return
    }

    var jsonResponse = JSON([:])
    
    jsonResponse["code"].stringValue = "200"
    jsonResponse["message"].stringValue = "popularity message augmenter "

    print("POST - /sigup \(jsonResponse.rawString)")
    //Log.debug("POST - /sigup \(jsonResponse.rawString)")
    try response.status(.OK).send(json: jsonResponse).end()
  }
}