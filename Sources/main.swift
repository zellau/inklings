// The Swift Programming Language
// https://docs.swift.org/swift-book

import Swifter
let server = HttpServer()
server["/octopus.png"] = shareFile("./octopus.png")
server["/"] = shareFile("./index.html")
// server["/my_html"] = scopes { 
//   html {
//     body {
//       h1 { inner = "hello" }
//     }
//   }
// }

try server.start(8081)
print("Server has started ( port = \(try server.port()) ). Try to connect now...")

//TODO exit on first line of input instead
//unfortunately readLine() blocks  e v e r y t h i n g
//bleh
import Dispatch
DispatchSemaphore(value: 0).wait()