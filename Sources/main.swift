// The Swift Programming Language
// https://docs.swift.org/swift-book

import Swifter
import SQLite

let server = HttpServer()
server["/octopus.png"] = shareFile("./octopus.png")
server["/inklings.css"] = shareFile("./inklings.css")
server["/"] = shareFile("./index.html")
server["/a"] = scopes { 
    html {
      header {
        addStylesheet();
      }
      body {
        makeHeader();
      }
    }
  }

try server.start(8081)
print("Server has started ( port = \(try server.port()) ). Try to connect now...")

//TODO exit on first line of input instead
//unfortunately readLine() blocks  e v e r y t h i n g
//bleh
import Dispatch
DispatchSemaphore(value: 0).wait()

func addStylesheet() -> () {
  link {
    rel = "stylesheet"
    href = "inklings.css"
  }
}

func makeHeader() -> () {
  return div {
    h1 {
      img {
        src = "octopus.png"
        width = "100"
        height = "100"
      }
      span {
        inner = "Inklings"
      }
    }
    nav {
      a {
        href="/"
        inner="Home"
      }
      span { inner = "|" }
      a {
        href="/bookshelf"
        inner="Boookshelf"
      }
      span { inner = "|" }
      a {
        href="/notebook"
        inner="Notebook"
      }
      span { inner = "|" }
      a {
        href="/account"
        inner="Account"
      }
      a {
        href="/search"
        classs = "right-align"
        inner="Search"
      }
    }
  }
}

// func makeHeader(request: HTTPRequest) -> HTTPResponse {
//     return h1 {
//         img { src = "octopus.png"}
//     }
//   //return "<h1> <img src='octopus.png' width='100' height='100' alt='🐙' /> Inklings</h1>";
// }