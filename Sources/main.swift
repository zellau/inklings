// The Swift Programming Language
// https://docs.swift.org/swift-book

/*
docker run -p 8081:8081 -v .\:/code --workdir /code -it swift:5.9 bash -c "apt update && apt install libsqlite3-dev && bash"
while swift run; [ $? == 35 ]; do continue; done  #restart on /z
docker stop $(docker ps --format '{{.Names}}')
*/

import Swifter
import SQLite
import Foundation

let server = HttpServer()
server["/octopus.png"] = shareFile("./octopus.png")
server["/inklings.css"] = shareFile("./inklings.css")

server["/z"] = { _ in
  print("Restarting...")
  exit(35)
}

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

  server["bookshelf"] = scopes {
    html {
      header {
        addStylesheet();
      }
    }
    body {
      makeHeader();
      showBookshelf(forUser: 1);
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

   server["/notebook/:notebook"] = { request in
     guard let notebook_id = Int("\(request.params[":notebook"]!)") else {
       //TODO: deal with this
       return HttpResponse.ok(.text("\(request.params[":notebook"])"))
     }
     return scopes {
      html {
        header {
          addStylesheet();
        }
        body {
          makeHeader();
          showNotebook(notebook_id, toUser: 1);
        }
      }
     }(request)
   }

   server["/notebook/:notebook/:page"] = { request in
     guard let notebook_id = Int("\(request.params[":notebook"]!)") else {
       //TODO: deal with this
       return HttpResponse.ok(.text("\(request.params[":notebook"])"))
     }
     guard let page_id = Int("\(request.params[":page"]!)") else {
       //TODO: deal with this
       return HttpResponse.ok(.text("\(request.params[":page"])"))
     }
     return scopes {
      html {
        header {
          addStylesheet();
        }
        body {
          makeHeader();
          showPage(page_id, inNotebook: notebook_id, toUser: 1);
        }
      }
     }(request)
   }

   server["/notebook/:notebook/:page/edit"] = { request in
     guard let notebook_id = Int("\(request.params[":notebook"]!)") else {
       //TODO: deal with this
       return HttpResponse.ok(.text("\(request.params[":notebook"])"))
     }
     guard let page_id = Int("\(request.params[":page"]!)") else {
       //TODO: deal with this
       return HttpResponse.ok(.text("\(request.params[":page"])"))
     }
     return scopes {
      html {
        header {
          addStylesheet();
        }
        body {
          makeHeader();
          editPage(page_id, inNotebook: notebook_id);
        }
      }
     }(request)
   }

  server.POST["/notebook/:notebook/:page/save"] = { request in
    guard let notebook_id = Int("\(request.params[":notebook"]!)") else {
      //TODO: deal with this
      return HttpResponse.ok(.text("\(request.params[":notebook"])"))
    }
    guard let page_id = Int("\(request.params[":page"]!)") else {
      //TODO: deal with this
      return HttpResponse.ok(.text("\(request.params[":page"])"))
    }
    var formData = [String: String]();
    for (key,value) in request.parseUrlencodedForm() {
      formData[key] = value;
    }
    let title = formData["title"]!;
    let textBody = formData["body"]!;

    savePage(page_id, inNotebook: notebook_id, title: title, textBody: textBody);

    return scopes {
      html {
        header {
          addStylesheet();
        }
        body {
          makeHeader();
          showPage(page_id, inNotebook: notebook_id, toUser: 1);
        }
      }
    }(request)
  }

   server["/notebook/:notebook/new"] = { request in
     guard let notebook_id = Int("\(request.params[":notebook"]!)") else {
       //TODO: deal with this
       return HttpResponse.ok(.text("\(request.params[":notebook"])"))
     }
     return scopes {
      html {
        header {
          addStylesheet();
        }
        body {
          makeHeader();
          editPage();
        }
      }
     }(request)
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
    href = "/inklings.css"
  }
}

func makeHeader() -> () {
  return div {
    h1 {
      img {
        src = "/octopus.png"
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
        inner="Bookshelf"
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

func showPage(_ pageID: Int, inNotebook notebookID: Int, toUser user: Int) {
  do {
    let pages = Table("pages");
    let user_storiesTable = Table("user_stories");
    let id = Expression<Int>("pageID")
    let title = Expression<String>("title")
    let body = Expression<String>("body")
    let storyID = Expression<Int>("storyID")
    let userID = Expression<Int>("userID")
    let role = Expression<Int>("role")

    let db = try Connection("inklings.sqlite3");
    let roleQuery = user_storiesTable.where(userID == user && storyID == notebookID)
    var userRole = 0;
    if let userStory = try db.pluck(roleQuery){
      userRole = userStory[role];
    }

    let query = pages.where(id == pageID)
    let page = try db.pluck(query)!

    if (userRole != 0) { //TODO: add more granularity to these roles
      div {
        idd = "viewPage";
        h2 {
          inner = page[title]
        }
        if (userRole == Roles.writer.rawValue) {
        a {
            href = "/notebook/\(notebookID)/\(pageID)/edit"
            inner = "Edit"
          }
        }
        p {
          classs = "notebook"
          inner = page[body]
        }
      }
      div {
        idd = "commentDiv";
        form {
          textarea {
            name = "comment";
            idd = "commentBox";
          }
          br {}
          input {
            type = "submit"
            value = "Save"
          }
        }
      }
    } else {
      h3 {
        inner = "You do not have permission to view this page."
      }
    }
   } catch {
    //log this probably
  }
}

func editPage(_ pageID: Int, inNotebook notebookID: Int) {
  do {
    let pages = Table("pages");
    let id = Expression<Int>("pageID")
    let title = Expression<String>("title")
    let body = Expression<String>("body")

    let db = try Connection("inklings.sqlite3");
    let query = pages.where(id == pageID)
    let page = try db.pluck(query)!

    form {
      action = "save"
      method = "POST"
      input {
        name = "title"
        type = "text"
        idd = "title"
        value = page[title]
      }
      br {}
      textarea {
        name = "body"
        idd = "body"
        inner = page[body]
      }
      br {}
      input {
        type = "submit"
        value = "Save"
      }
    }
   } catch {
    //log this probably
  }
}

func savePage(_ pageID: Int, inNotebook notebookID: Int, title: String, textBody: String) {
  do {
    //TODO: check that the user is allowed to do this
    let pages = Table("pages");
    let id = Expression<Int>("pageID")
    let titleExpression = Expression<String>("title")
    let bodyExpression = Expression<String>("body")

    let db = try Connection("inklings.sqlite3");
    let page = pages.filter(id == pageID);
    try db.run(page.update(titleExpression <- title, bodyExpression <- textBody));
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

func showBookshelf(forUser user: Int) {
  do {
    let user_stories = Table("user_stories");
    let stories = Table("stories");

    let storyID = Expression<Int>("storyID")
    let userID = Expression<Int>("userID")
    let role = Expression<Int>("role")
    let title = Expression<String>("title")
    let description = Expression<String>("description")

    let db = try Connection("inklings.sqlite3");
    let bookshelfStories = user_stories.where(userID == user && role != Roles.writer.rawValue)
    for story in try db.prepare(bookshelfStories) {
      let notebooks = stories.where(storyID == story[storyID])
      for notebook in try db.prepare(notebooks) {
        a {
          classs = "blocklink"
          href = "/notebook/\(notebook[storyID])"
          h2 {
            inner = notebook[title]
          }
          p {
            inner = notebook[description]
          }
        }
      }
    }
   } catch {
    //log this probably
  }
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
        a {
          classs = "blocklink"
          href = "/notebook/\(notebook[storyID])"
          h2 {
            inner = notebook[title]
          }
          p {
            inner = notebook[description]
          }
        }
      }
    }
    a {
      classs = "blocklink"
      href = "/notebook/new"
      h2 {
        inner = "New notebook"
      }
    }
   } catch {
    //log this probably
  }
}

func showNotebook(_ notebookID: Int, toUser user: Int) { //TODO: add user specific logic
  do {
    let user_storiesTable = Table("user_stories");
    let storiesTable = Table("stories");
    let pagesTable = Table("pages");

    let storyID = Expression<Int>("storyID")
    let title = Expression<String>("title")
    let description = Expression<String>("description")
    let pageID = Expression<Int>("pageID")

    let userID = Expression<Int>("userID")
    let role = Expression<Int>("role")

    let db = try Connection("inklings.sqlite3");
    let roleQuery = user_storiesTable.where(userID == user && storyID == notebookID)
    var userRole = 0;
    if let userStory = try db.pluck(roleQuery){
      userRole = userStory[role];
    }
    let query = storiesTable.where(storyID == notebookID)
    guard let story = try db.pluck(query) else {
      h1 {
        inner = "This story does not exist."
      }
      return;
    }
    h2 {
      inner = story[title];
    }
    p {
      inner = story[description];
    }
    if (userRole != 0) {
      let pages = pagesTable.where(storyID == notebookID);
      for page in try db.prepare(pages) {
        a {
          classs = "blocklink"
          href = "/notebook/\(notebookID)/\(page[pageID])"
          h3 {
            inner = page[title]
          }
        }
      }
      if (userRole == Roles.writer.rawValue) {
        a {
          classs = "blocklink"
          href = "/notebook/\(notebookID)/new"
          h3 {
            inner = "New page"
          }
        }
      }
    } else {
      h3 {
        inner = "You do not have permission to view this story. Request?"
      }
      a {
        inner = "Request permission"
      }
      //TODO: make this work better with public stories
    }
   } catch {
    //log this probably
  }
}

func editPage() {
  //do {
    // let pages = Table("pages");
    // let id = Expression<Int>("pageID")
    // let title = Expression<String>("title")
    // let body = Expression<String>("body")

    // let db = try Connection("inklings.sqlite3");
    // let query = pages.where(id == pageID)
    // let page = try db.pluck(query)!

    // h2 {
    //   inner = page[title]
    // }
    // p {
    //   classs = "notebook"
    //   inner = page[body]
    //}
   //} catch {
    //log this probably
  //}
}