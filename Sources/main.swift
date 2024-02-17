// The Swift Programming Language
// https://docs.swift.org/swift-book

import Swifter
import SQLite

let server = HttpServer()
server["/octopus.png"] = shareFile("./octopus.png")
server["/inklings.css"] = shareFile("./inklings.css")
server["/a"] = shareFile("./index.html")
server["/"] = scopes { 
    html {
      header {
        addStylesheet();
      }
      body {
        makeHeader();
        showPage(1);
      }
    }
  }

  server["/notebooks"] = scopes { 
    html {
      header {
        addStylesheet();
      }
      body {
        makeHeader();
        showNotebooks(forUser: 1);
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
        href="/notebooks"
        inner="Notebooks"
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

func showPage(_ pageID: Int) {
  do {
    let pages = Table("pages");
    let id = Expression<Int>("pageID")
    let title = Expression<String>("title")
    let body = Expression<String>("body")

    let db = try Connection("inklings.sqlite3");
    let query = pages.where(id == pageID)
    let page = try db.pluck(query)!

    h2 {
      inner = page[title]
    }
    p {
      classs = "notebook"
      inner = page[body]
    }
   } catch {
    //log this probably
  }
}

enum Roles: Int {
  case writer = 1
  case editor
  case beta
  case reader
}

func showNotebooks(forUser user: Int) {
  do {
    let user_stories = Table("user_stories");
    let stories = Table("stories");

    let storyID = Expression<Int>("storyID")
    let userID = Expression<Int>("userID")
    let role = Expression<Int>("role")
    let title = Expression<String>("title")
    let description = Expression<String>("description")

    let db = try Connection("inklings.sqlite3");
    let notebookStories = user_stories.where(userID == user && role == Roles.writer.rawValue)
    for story in try db.prepare(notebookStories) {
      let notebooks = stories.where(storyID == story[storyID])
      for notebook in try db.prepare(notebooks) {
        h2 {
          inner = "\(notebook[title])"
        }
        p {
          inner = notebook[description]
        }
      }
    }
   } catch {
    //log this probably
  }
}