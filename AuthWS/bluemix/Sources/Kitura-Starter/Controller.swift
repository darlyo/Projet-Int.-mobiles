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

public class Controller {

  let router: Router
  let appEnv: AppEnv

  let Auth_port = 15544 as Int32
  let Auth_host = "sl-eu-lon-2-portal.2.dblayer.com"
  let Auth_password = "LTWCJWJPVKKGMUGZ"

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
    router.all("/", middleware: StaticFileServer())
    router.all("/", middleware: BodyParser())

    // Basic GET request
    router.get("/hello", handler: getHello)

    // Basic POST request
    router.post("/hello", handler: postHello)
    router.post("/salut", handler: postHello)

    // JSON Get request
    router.get("/json", handler: getJSON)

    // Check token, GET request
    router.get("/check/:token", handler: checkToken)

    // Connect user, POST request
    router.post("/connect", handler: postConnect)

    // Disconnect user, POST request
    router.post("/disconnect", handler: postDisconnect)

    // Disconnect user, POST request
    router.post("/signup", handler: postSignUp)
  }


  func generateToken() -> String {

    let length = 8
      let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      let len = UInt32(62)

      var randomString = ""

      for _ in 0 ..< length {
    #if os(Linux)
          let rand = Int(random() % 62)
    #else
      let rand = Int(arc4random_uniform(len))
    #endif

          let nextChar = letters.character(at: Int(rand))
          //randomString += NSString(characters: &nextChar, length: 1) as String
          randomString += String(nextChar)
      }

      return randomString
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

  public func getHello(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("GET - /hello route handler...")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    let rand = generateToken()
    try response.status(.OK).send("Hello from Kitura-Starter!  : \(rand)").end()
  }

  public func postHello(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("POST - /hello route handler...")
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    if let name = try request.readString() {
      try response.status(.OK).send("Hello \(name), from Kitura-Starter!").end()
    } else {
      try response.status(.OK).send("Kitura-Starter received a POST request!").end()
    }
  }

  public func getJSON(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws {
    Log.debug("GET - /json route handler...")
    response.headers["Content-Type"] = "application/json; charset=utf-8"
    var jsonResponse = JSON([:])
    jsonResponse["framework"].stringValue = "Kitura"
    jsonResponse["applicationName"].stringValue = "Kitura-Starter"
    jsonResponse["company"].stringValue = "IBM"
    jsonResponse["organization"].stringValue = "Swift @ IBM"
    jsonResponse["location"].stringValue = "Austin, Texas"
    try response.status(.OK).send(json: jsonResponse).end()
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
        jsonResponse["code"].stringValue = "503"
        jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"

        //response.send("error")
      }

      else {
        print("Connected to Redis")
        // set a key
        redis.ttl(token) { (time: TimeInterval?, redisError: NSError?) in
          if let error = redisError {
            jsonResponse["code"].stringValue = "401"
            jsonResponse["message"].stringValue = "Erreur cmd redis ttl: \(error)"                
          }
          else if time! == -1 {
            jsonResponse["code"].stringValue = "408"
            jsonResponse["message"].stringValue = "token invalide, time expire"
            //response.send("token invalide, time expire")
          }
          else if time! == -2 {
            jsonResponse["code"].stringValue = "408"
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
          jsonResponse["code"].stringValue = "503"
          jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
        }

        else
        {
          redis.get(user) { (pass: RedisString?, redisError: NSError?) in

            if let error = redisError {
              jsonResponse["code"].stringValue = "401"
              jsonResponse["message"].stringValue = "Erreur cmd redis get \(user): \(error)"
            }
            else if let mdp = pass {
              if mdp.asString == password {
                let rand = random()
                redis.set(String(rand),value: user,exists: false,expiresIn: (60000 as TimeInterval)){ (ok: Bool?, redisError: NSError?) in
                  if let error = redisError {
                    jsonResponse["code"].stringValue = "401"
                    jsonResponse["message"].stringValue = "Erreur cmd redis set token: \(error)"              
                  }
                  else {
                    jsonResponse["code"].stringValue = "200"
                    jsonResponse["message"].stringValue = "\(rand)"              
                  }
                }
              }
              else {
                jsonResponse["code"].stringValue = "401"
                jsonResponse["message"].stringValue = "Invalide password"
              }
            }
            else {
              jsonResponse["code"].stringValue = "401"
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
          jsonResponse["code"].stringValue = "503"
          jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
        }

        else
        {
          redis.get(token) { (u: RedisString?, redisError: NSError?) in

            if let error = redisError {
              jsonResponse["code"].stringValue = "401"
              jsonResponse["message"].stringValue = "Erreur cmd redis get \(user_redis): \(error)"
            }

            else if let user = u {
              if user.asString == user_redis {

                redis.expire(token,inTime: (1 as TimeInterval)) { (ok: Bool?, redisError: NSError?) in
                  if let error = redisError {
                    jsonResponse["code"].stringValue = "408"
                    jsonResponse["message"].stringValue = "Erreur cmd redis expire : \(error)"              
                  }
                  else {
                    jsonResponse["code"].stringValue = "200"
                    jsonResponse["message"].stringValue = "disconnect"              
                  }
                }
              }
              else {
                jsonResponse["code"].stringValue = "401"
                jsonResponse["message"].stringValue = "Invalide user"
              }
            }
            else {
              jsonResponse["code"].stringValue = "408"
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
          jsonResponse["code"].stringValue = "503"
          jsonResponse["message"].stringValue = "Erreur connect redis: \(error)"
        }

        else
        {
          redis.set(user, value:password,exists:false) { (ok: Bool?, redisError: NSError?) in

            if let error = redisError {
              jsonResponse["code"].stringValue = "401"
              jsonResponse["message"].stringValue = "Erreur cmd redis set \(user): \(error)"
            }
            else if ok == true {                
                jsonResponse["code"].stringValue = "200"
                jsonResponse["message"].stringValue = "user create"              
            }
            else {
              jsonResponse["code"].stringValue = "401"
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
}
