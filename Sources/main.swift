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
server["/Handwriting-Regular.otf"] = shareFile("./Handwriting-Regular.otf")
server["/Handwriting-Bold.otf"] = shareFile("./Handwriting-Bold.otf")
server["/Handwriting-Italic.otf"] = shareFile("./Handwriting-Italic.otf")

// Serve custom uploaded fonts
server["/fonts/:filename"] = { request in
    let filename = request.params[":filename"] ?? ""
    let path = "./uploads/fonts/\(filename)"
    return shareFile(path)(request)
}

server["/z"] = { _ in
  print("Restarting...")
  exit(35)
}

// Login route
server["/login"] = { request in
    if let token = request.queryParams.first(where: { $0.0 == "token" })?.1 {
        if let userID = getUserByMagicToken(token) {
            let sessionID = createSession(forUser: userID)
            return HttpResponse.raw(303, "See Other", [
                "Location": "/",
                "Set-Cookie": "session=\(sessionID); Path=/; HttpOnly; Max-Age=2592000"
            ], nil)
        }
    }
    // Invalid or missing token
    return scopes {
        html {
            head {
                addStylesheet()
            }
            body {
                makeHeader()
                div {
                    classs = "accountPage"
                    h2 {
                        inner = "Login"
                    }
                    p {
                        inner = "Invalid or missing login token."
                    }
                }
            }
        }
    }(request)
}

// Logout route
server.POST["/logout"] = { request in
    return HttpResponse.raw(303, "See Other", [
        "Location": "/",
        "Set-Cookie": "session=; Path=/; HttpOnly; Max-Age=0"
    ], nil)
}

server["/"] = scopes { 
    html {
      head {
        addStylesheet();
      }
      body {
        makeHeader();
        showPage("lorem-ipsum", inNotebook: "tests", toUser: 0);
      }
    }
  }

  server["bookshelf"] = { request in
    let userID = getCurrentUser(from: request) ?? 0
    return scopes {
      html {
        head {
          addStylesheet()
        }
        body {
          makeHeader()
          showBookshelf(forUser: userID)
        }
      }
    }(request)
  }

  server["/notebooks"] = { request in
    let userID = getCurrentUser(from: request) ?? 0
    return scopes {
      html {
        head {
          addStylesheet()
        }
        body {
          makeHeader()
          showNotebooks(forUser: userID)
        }
      }
    }(request)
  }

   // Handle notebook creation
   server.POST["/notebook/create"] = { request in
     var formData = [String: String]()
     for (key, value) in request.parseUrlencodedForm() {
       formData[key] = value
     }
     
     let title = formData["title"] ?? "Untitled"
     let description = formData["description"] ?? ""
     
     let userID = getCurrentUser(from: request) ?? 0
     let newNotebookID = createNotebook(title: title, description: description, userID: userID)
     
     return HttpResponse.raw(303, "See Other", ["Location": "/notebook/\(newNotebookID)"], nil)
   }

   server["/notebook/:notebook"] = { request in
     let notebookParam = request.params[":notebook"] ?? ""
     
     // Handle /notebook/new specially
     if notebookParam == "new" {
       let userID = getCurrentUser(from: request) ?? 0
       let userPrefs = getUserPreferences(forUser: userID)
       let inputStyle = "font-family: \(userPrefs.font); color: \(userPrefs.color);"
       
       return scopes {
         html {
           head {
             addStylesheet()
           }
           body {
             makeHeader()
             div {
               idd = "newNotebookPage"
               classs = "accountPage"
               h2 {
                 inner = "Create New Notebook"
               }
               form {
                 action = "/notebook/create"
                 method = "POST"
                 div {
                   classs = "form-group"
                   input {
                     type = "text"
                     name = "title"
                     idd = "title"
                     placeholder = "Title"
                     style = inputStyle
                   }
                 }
                 div {
                   classs = "form-group"
                   style = "display: flex; align-items: flex-start;"
                   textarea {
                     name = "description"
                     idd = "description"
                     placeholder = "Give a description for your notebook"
                     rows = "4"
                     style = "width: 50%; \(inputStyle)"
                   }
                 }
                 button {
                   type = "submit"
                   classs = "save-button"
                   inner = "Create Notebook"
                 }
               }
             }
           }
         }
       }(request)
     }
     
     guard notebookExists(notebookParam) else {
       return HttpResponse.notFound()
     }
     return scopes {
      html {
        head {
          addStylesheet();
        }
        body {
          makeHeader();
          let userID = getCurrentUser(from: request) ?? 0
          showNotebook(notebookParam, toUser: userID);
        }
      }
     }(request)
   }

   server["/notebook/:notebook/:page"] = { request in
     let notebookID = request.params[":notebook"] ?? ""
     guard notebookExists(notebookID) else {
       return HttpResponse.notFound()
     }

     let pageID = request.params[":page"] ?? ""
     
     // Handle /notebook/:notebook/new specially
     if pageID == "new" {
      let userID = getCurrentUser(from: request) ?? 0
      let userPrefs = getUserPreferences(forUser: userID)

      return scopes {
        html {
          head {
            addStylesheet();
          }
          body {
            makeHeader();
            editPage(nil, inNotebook: notebookID, forUser: userID);
          }
      }
     }(request)
     }

     guard pageExists(pageID, inNotebook: notebookID) else {
       return HttpResponse.notFound()
     }
     return scopes {
      html {
        head {
          addStylesheet();
        }
        body {
          makeHeader();
          let userID = getCurrentUser(from: request) ?? 0
          showPage(pageID, inNotebook: notebookID, toUser: userID);
        }
      }
     }(request)
   }

   server["/notebook/:notebook/:page/edit"] = { request in
     let userID = getCurrentUser(from: request) ?? 0
     let notebookID = request.params[":notebook"] ?? ""
     guard notebookExists(notebookID) else {
       return HttpResponse.notFound()
     }
     let pageID = request.params[":page"] ?? ""
     guard pageExists(pageID, inNotebook: notebookID) else {
       return HttpResponse.notFound()
     }
     return scopes {
      html {
        head {
          addStylesheet();
        }
        body {
          makeHeader();
          editPage(pageID, inNotebook: notebookID, forUser: userID);
        }
      }
     }(request)
   }

  server.POST["/notebook/:notebook/:page/save"] = { request in
    let notebookID = request.params[":notebook"] ?? ""
    guard notebookExists(notebookID) else {
      return HttpResponse.notFound()
    }
    let pageID = request.params[":page"] ?? ""
    guard pageExists(pageID, inNotebook: notebookID) else {
      return HttpResponse.notFound()
    }
    var formData = [String: String]();
    for (key,value) in request.parseUrlencodedForm() {
      formData[key] = value;
    }
    let title = formData["title"]!;
    let textBody = formData["body"]!;

    savePage(pageID, inNotebook: notebookID, title: title, textBody: textBody);

    return HttpResponse.raw(303, "See Other", ["Location": "/notebook/\(notebookID)/\(pageID)"], nil)
  }

server.POST["/notebook/:notebook/page/create"] = { request in
    let notebookID = request.params[":notebook"] ?? ""
    guard notebookExists(notebookID) else {
      return HttpResponse.notFound()
    }
    var formData = [String: String]();
    for (key,value) in request.parseUrlencodedForm() {
      formData[key] = value;
    }
    let title = formData["title"]!;
    let textBody = formData["body"]!;

    let newPageID = createPage(inNotebook: notebookID, title: title, textBody: textBody);

    return HttpResponse.raw(303, "See Other", ["Location": "/notebook/\(notebookID)/\(newPageID)"], nil)
  }

server.POST["/search"] = { request in
    var formData = [String: String]()
    for (key, value) in request.parseUrlencodedForm() {
      formData[key] = value
    }
    let query = formData["q"] ?? ""
    let userID = getCurrentUser(from: request) ?? 0
    
    return scopes {
      html {
        head {
          addStylesheet()
        }
        body {
          makeHeader()
          showSearchResults(query: query, forUser: userID)
        }
      }
    }(request)
  }

// Account page
server["/account"] = { request in
    let userID = getCurrentUser(from: request) ?? 0
    // Get message from query params if present
    let message = request.queryParams.first(where: { $0.0 == "message" })?.1.replacingOccurrences(of: "+", with: " ")
    
    return scopes {
        html {
            head {
                addStylesheet()
            }
            body {
                makeHeader()
                showAccountPage(forUser: userID, message: message)
            }
        }
    }(request)
}

server.POST["/account/save"] = { request in
    let userID = getCurrentUser(from: request) ?? 0
    var formData = [String: String]()
    for (key, value) in request.parseUrlencodedForm() {
        formData[key] = value
    }
    
    let color = formData["color"] ?? "#333333"
    let font = formData["font"] ?? "Handwriting"
    
    saveUserPreferences(userID: userID, color: color, font: font)
    
    return HttpResponse.raw(303, "See Other", ["Location": "/account?message=Preferences+saved!"], nil)
}

server.POST["/account/upload-font"] = { request in
    let userID = getCurrentUser(from: request) ?? 0
    let multipart = request.parseMultiPartFormData()
    
    var fontName: String = ""
    var fontData: [UInt8]? = nil
    var originalFilename: String = ""
    
    for part in multipart {
        if part.name == "fontName" {
            fontName = String(bytes: part.body, encoding: .utf8) ?? ""
        } else if part.name == "fontFile" {
            fontData = part.body
            originalFilename = part.fileName ?? "font.otf"
        }
    }
    
    var message = "Please+provide+a+font+name+and+file."
    
    if !fontName.isEmpty, let data = fontData, !data.isEmpty {
        // Generate unique filename
        let fileExtension = (originalFilename as NSString).pathExtension
        let safeFileName = "\(UUID().uuidString).\(fileExtension)"
        let filePath = "./uploads/fonts/\(safeFileName)"
        
        // Save the file
        let fileURL = URL(fileURLWithPath: filePath)
        do {
            try Data(data).write(to: fileURL)
            saveCustomFont(userID: userID, fontName: fontName, fileName: safeFileName)
            message = "Font+uploaded+successfully!"
        } catch {
            message = "Error+saving+font+file."
        }
    }
    
    return HttpResponse.raw(303, "See Other", ["Location": "/account?message=\(message)"], nil)
}

server.POST["/account/reset-token"] = { request in
    guard let userID = getCurrentUser(from: request) else {
        return HttpResponse.raw(303, "See Other", ["Location": "/"], nil)
    }
    
    // Generate new magic token
    let newToken = generateWhimsicalToken()
    
    // Update user's magic token and delete all their sessions
    do {
        let db = try Connection("inklings.sqlite3")
        try db.run("UPDATE users SET magicToken = ? WHERE userID = ?", newToken, userID)
        try db.run("DELETE FROM sessions WHERE userID = ?", userID)
    } catch {
        return HttpResponse.raw(303, "See Other", ["Location": "/account?message=Error+resetting+token"], nil)
    }
    
    // Clear session cookie and redirect to login page with message
    return HttpResponse.raw(303, "See Other", [
        "Location": "/",
        "Set-Cookie": "session=; Path=/; HttpOnly; Max-Age=0"
    ], nil)
}

server.POST["/notebook/:notebook/:page/comment"] = { request in
    let notebookID = request.params[":notebook"] ?? ""
    guard notebookExists(notebookID) else {
      return HttpResponse.badRequest(.text("Invalid notebook"))
    }
    let pageID = request.params[":page"] ?? ""
    guard pageExists(pageID, inNotebook: notebookID) else {
      return HttpResponse.badRequest(.text("Invalid page"))
    }
    
    var formData = [String: String]()
    for (key, value) in request.parseUrlencodedForm() {
      formData[key] = value
    }
    
    let commentText = formData["comment"] ?? ""
    let selectedText = formData["selectedText"]
    let startOffset = formData["startOffset"].flatMap { Int($0) }
    let endOffset = formData["endOffset"].flatMap { Int($0) }
    
    if !commentText.isEmpty {
      let userID = getCurrentUser(from: request) ?? 0
      saveComment(notebookID: notebookID, pageID: pageID, userID: userID, commentText: commentText, selectedText: selectedText, startOffset: startOffset, endOffset: endOffset)
    }
    
    return HttpResponse.raw(303, "See Other", ["Location": "/notebook/\(notebookID)/\(pageID)"], nil)
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
      form {
        action = "/search"
        method = "POST"
        classs = "right-align"
        input {
          type = "text"
          name = "q"
          placeholder = "Search..."
        }
        button {
          type = "submit"
          classs = "search-button"
        }
      }
    }
  }
}

func showPage(_ pageID: String, inNotebook notebookID: String, toUser user: Int) {
  do {
    let pages = Table("pages");
    let user_storiesTable = Table("user_stories");
    let idExpression = Expression<String>("id")
    let notebookIDExpression = Expression<String>("notebookID")
    let title = Expression<String>("title")
    let body = Expression<String>("body")
    let userID = Expression<Int>("userID")
    let role = Expression<Int>("role")

    let db = try Connection("inklings.sqlite3");
    let roleQuery = user_storiesTable.where(userID == user && notebookIDExpression == notebookID)
    var userRole = 0;
    if let userStory = try db.pluck(roleQuery){
      userRole = userStory[role];
    }

    let query = pages.where(idExpression == pageID && notebookIDExpression == notebookID)
    let page = try db.pluck(query)!

    if (userRole != 0) { //TODO: add more granularity to these roles
      // Fetch comments and generate custom font CSS
      let comments = getComments(forPage: pageID, inNotebook: notebookID)
      var customFontCSS = ""
      var seenFontIDs = Set<Int>()
      for comment in comments {
          if comment.fontName.starts(with: "custom-") {
              if let fontIDStr = comment.fontName.split(separator: "-").last,
                 let fontID = Int(fontIDStr),
                 !seenFontIDs.contains(fontID) {
                  seenFontIDs.insert(fontID)
                  if let fontInfo = getCustomFontByID(fontID) {
                      customFontCSS += "@font-face { font-family: '\(comment.fontName)'; src: url('/fonts/\(fontInfo.fileName)'); }\n"
                  }
              }
          }
      }

      let userPrefs = getUserPreferences(forUser: user)
      let inputStyle = "font-family: \(userPrefs.font); color: \(userPrefs.color);"

      
      // Add style tag for custom fonts
      if !customFontCSS.isEmpty {
          style {
              inner = customFontCSS
          }
      }
      
      div {
        idd = "pageContainer"
        // Left side: page content and comments
        div {
          idd = "leftColumn"
          div {
            idd = "viewPage"
            h2 {
              inner = page[title]
            }
            if (userRole == Roles.writer.rawValue) {
              a {
                href = "/notebook/\(notebookID)/\(pageID)/edit"
                inner = "Edit"
              }
            }
            div {
              idd = "pageBody"
              inner = renderBodyWithInlineComments(page[body], comments: comments)
            }
          }
          div {
            idd = "commentSection"
            h3 {
              inner = "General Comments"
            }
            // Display only general comments (those without selected text) - inline comments appear in the body
            let generalComments = comments.filter { $0.selectedText == nil }
            for comment in generalComments {
              let fontFamily = comment.fontName.starts(with: "custom-") ? "'\(comment.fontName)'" : comment.fontName
              div {
                classs = "comment"
                p {
                  classs = "comment-text"
                  style = "color: \(comment.fontColor); font-family: \(fontFamily);"
                  inner = comment.commentText
                }
                p {
                  classs = "comment-author"
                  style = "color: \(comment.fontColor); font-family: \(fontFamily);"
                  inner = "- \(comment.userName)"
                }
              }
            }
            if generalComments.isEmpty {
              p {
                classs = "no-comments"
                inner = "No general comments yet."
              }
            }
          }
        }
        // Right side: sticky comment form
        div {
          idd = "commentFormContainer"
          h4 {
            inner = "Add a Comment"
          }
          div {
            idd = "selectionInfo"
            classs = "hidden"
            span {
              inner = "Commenting on: "
            }
            span {
              idd = "selectedTextDisplay"
            }
            br {}
            button {
              type = "button"
              idd = "clearSelection"
              inner = "Clear selection"
            }
          }
          form {
            action = "/notebook/\(notebookID)/\(pageID)/comment"
            method = "POST"
            idd = "commentForm"
            input {
              type = "hidden"
              name = "selectedText"
              idd = "selectedTextInput"
            }
            input {
              type = "hidden"
              name = "startOffset"
              idd = "startOffsetInput"
            }
            input {
              type = "hidden"
              name = "endOffset"
              idd = "endOffsetInput"
            }
            textarea {
              name = "comment"
              idd = "commentBox"
              style = inputStyle
              placeholder = "Select text to comment on a specific part, or write a general comment."
            }
            br {}
            input {
              type = "submit"
              value = "Post Comment"
            }
          }
        }
      }
      script {
        inner = """
        document.addEventListener('DOMContentLoaded', function() {
          const pageBody = document.getElementById('pageBody');
          const selectedTextInput = document.getElementById('selectedTextInput');
          const startOffsetInput = document.getElementById('startOffsetInput');
          const endOffsetInput = document.getElementById('endOffsetInput');
          const selectionInfo = document.getElementById('selectionInfo');
          const selectedTextDisplay = document.getElementById('selectedTextDisplay');
          const clearSelectionBtn = document.getElementById('clearSelection');
          
          function clearSelection() {
            selectedTextInput.value = '';
            startOffsetInput.value = '';
            endOffsetInput.value = '';
            selectionInfo.classList.add('hidden');
          }
          
          pageBody.addEventListener('mouseup', function() {
            const selection = window.getSelection();
            const selectedText = selection.toString().trim();
            
            if (selectedText.length > 0) {
              const range = selection.getRangeAt(0);
              const preSelectionRange = range.cloneRange();
              preSelectionRange.selectNodeContents(pageBody);
              preSelectionRange.setEnd(range.startContainer, range.startOffset);
              const startOffset = preSelectionRange.toString().length;
              const endOffset = startOffset + selectedText.length;
              
              selectedTextInput.value = selectedText;
              startOffsetInput.value = startOffset;
              endOffsetInput.value = endOffset;
              selectedTextDisplay.textContent = '"' + (selectedText.length > 50 ? selectedText.substring(0, 50) + '...' : selectedText) + '"';
              selectionInfo.classList.remove('hidden');
            } else {
              clearSelection();
            }
          });
          
          clearSelectionBtn.addEventListener('click', function() {
            clearSelection();
            window.getSelection().removeAllRanges();
          });
          
          // Track whether any comment is expanded (disables hover) - defined early for use below
          let hasExpandedComment = false;
          
          function updateExpandedState() {
            hasExpandedComment = document.querySelectorAll('.inline-comment.expanded').length > 0;
          }
          
          // Toggle inline comment expansion on click
          // Click on comment itself to expand it
          document.querySelectorAll('.inline-comment').forEach(function(comment) {
            comment.addEventListener('click', function(e) {
              e.stopPropagation();
              // Close any other expanded comments
              document.querySelectorAll('.inline-comment.hovered').forEach(function(c) {
                c.classList.remove('hovered');
              });
              document.querySelectorAll('.inline-comment.expanded').forEach(function(other) {
                if (other !== comment) other.classList.remove('expanded');
              });
              comment.classList.toggle('expanded');
              updateExpandedState();
            });
          });
          
          // Click on underlined text to cycle through associated comments
          document.querySelectorAll('.commented-text').forEach(function(underlined) {
            underlined.style.cursor = 'pointer';
            underlined.addEventListener('click', function(e) {
              e.stopPropagation();
              // Remove hover highlighting
              document.querySelectorAll('.inline-comment.hovered').forEach(function(c) {
                c.classList.remove('hovered');
              });
              const commentIDs = underlined.getAttribute('data-comment-ids');
              if (!commentIDs) return;
              
              const ids = commentIDs.split(',');
              // Find all inline-comments with matching IDs
              const comments = [];
              ids.forEach(function(id) {
                const comment = document.querySelector('.inline-comment[data-comment-id="' + id + '"]');
                if (comment) comments.push(comment);
              });
              
              if (comments.length === 0) return;
              
              // Close any comments not in this group
              document.querySelectorAll('.inline-comment.expanded').forEach(function(other) {
                if (!comments.includes(other)) other.classList.remove('expanded');
              });
              
              if (comments.length === 1) {
                // Single comment: just toggle it
                comments[0].classList.toggle('expanded');
              } else {
                // Multiple comments: cycle through them
                // Find which one (if any) is currently expanded
                let currentIndex = -1;
                for (let i = 0; i < comments.length; i++) {
                  if (comments[i].classList.contains('expanded')) {
                    currentIndex = i;
                    break;
                  }
                }
                
                // Collapse current, expand next (or first if none expanded, or none if at end)
                if (currentIndex >= 0) {
                  comments[currentIndex].classList.remove('expanded');
                  if (currentIndex < comments.length - 1) {
                    comments[currentIndex + 1].classList.add('expanded');
                  }
                  // If at last comment, next click collapses all (already done above)
                } else {
                  // None expanded, expand first
                  comments[0].classList.add('expanded');
                }
              }
              updateExpandedState();
            });
          });
          
          // Close expanded comments when clicking elsewhere
          document.addEventListener('click', function(e) {
            if (!e.target.closest('.comment-anchor')) {
              document.querySelectorAll('.inline-comment.expanded').forEach(function(c) {
                c.classList.remove('expanded');
              });
              updateExpandedState();
            }
          });
          
          // Hover on underlined text highlights associated comments (only when nothing is expanded)
          document.querySelectorAll('.commented-text').forEach(function(underlined) {
            underlined.addEventListener('mouseenter', function() {
              if (hasExpandedComment) return;
              const commentIDs = underlined.getAttribute('data-comment-ids');
              if (!commentIDs) return;
              const ids = commentIDs.split(',');
              ids.forEach(function(id) {
                const comment = document.querySelector('.inline-comment[data-comment-id="' + id + '"]');
                if (comment) comment.classList.add('hovered');
              });
            });
            underlined.addEventListener('mouseleave', function() {
              document.querySelectorAll('.inline-comment.hovered').forEach(function(c) {
                c.classList.remove('hovered');
              });
            });
          });
        });
        """
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

func editPage(_ pageID: String?, inNotebook notebookID: String, forUser userID: Int) {
  do {
    let pages = Table("pages");
    let idExpression = Expression<String>("id")
    let notebookIDExpression = Expression<String>("notebookID")
    
    let titleExpression = Expression<String>("title")
    let bodyExpression = Expression<String>("body")

    let db = try Connection("inklings.sqlite3");

    let userPrefs = getUserPreferences(forUser: userID)
    let inputStyle = "font-family: \(userPrefs.font); color: \(userPrefs.color);"

    var currentTitle = ""
    var currentBody = ""
    var formAction = "/notebook/\(notebookID)/page/create"
    
    if let existingID = pageID {
      // Editing existing page - load its content
      let query = pages.where(idExpression == existingID && notebookIDExpression == notebookID)
      if let page = try db.pluck(query) {
        currentTitle = page[titleExpression]
        currentBody = page[bodyExpression]
        formAction = "/notebook/\(notebookID)/\(existingID)/save"
      }
    }
    // If pageID is nil, we're creating a new page - leave title/body empty

    form {
      action = formAction
      method = "POST"
      style = "margin-top: 5px;"
      input {
        name = "title"
        type = "text"
        idd = "title"
        placeholder = "Title"
        style = inputStyle
        value = currentTitle
      }
      br {}
      textarea {
        name = "body"
        idd = "body"
        placeholder = "Body"
        inner = currentBody
        style = inputStyle
      }
      br {}
      button {
        type = "submit"
        classs = "save-button"
        inner = "Save"
      }
    }
   } catch {
    //log this probably
  }
}

func savePage(_ pageID: String, inNotebook notebookID: String, title: String, textBody: String) {
  do {
    //TODO: check that the user is allowed to do this
    let pages = Table("pages");
    let idExpression = Expression<String>("id")
    let notebookIDExpression = Expression<String>("notebookID")
    let titleExpression = Expression<String>("title")
    let bodyExpression = Expression<String>("body")

    let db = try Connection("inklings.sqlite3");
    
    let page = pages.filter(idExpression == pageID && notebookIDExpression == notebookID)
    try db.run(page.update(titleExpression <- title, bodyExpression <- textBody));
  } catch {
    print("Error saving page: \(error)")
  }
}

func createPage(inNotebook notebookID: String, title: String, textBody: String) -> String {
  do {
    let db = try Connection("inklings.sqlite3");
    let id = generateUniquePageID(from: title, inNotebook: notebookID)
    let insertPage = "INSERT INTO pages (id, notebookID, title, body) VALUES (?, ?, ?, ?)"
    try db.run(insertPage, id, notebookID, title, textBody)
    return id
  } catch {
    print("Error creating page: \(error)")
    return "error"
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
    let user_stories = Table("user_stories")
    let stories = Table("stories")
    let users = Table("users")

    let notebookIDExpression = Expression<String>("notebookID")
    let idExpression = Expression<String>("id")
    let userID = Expression<Int>("userID")
    let role = Expression<Int>("role")
    let title = Expression<String>("title")
    let description = Expression<String>("description")
    let userName = Expression<String>("name")

    let db = try Connection("inklings.sqlite3")
    let bookshelfStories = user_stories.where(userID == user && role != Roles.writer.rawValue)
    for story in try db.prepare(bookshelfStories) {
      let notebookID = story[notebookIDExpression]
      let notebooks = stories.where(idExpression == notebookID)
      for notebook in try db.prepare(notebooks) {
        // Find the writer(s) for this story
        let writerQuery = user_stories.where(notebookIDExpression == notebookID && role == Roles.writer.rawValue)
        var writerNames: [String] = []
        for writer in try db.prepare(writerQuery) {
          let writerUserQuery = users.where(userID == writer[userID])
          if let writerUser = try db.pluck(writerUserQuery) {
            writerNames.append(writerUser[userName])
          }
        }
        let writerString = writerNames.isEmpty ? "Unknown" : writerNames.joined(separator: ", ")
        
        a {
          classs = "blocklink"
          href = "/notebook/\(notebookID)"
          h2 {
            inner = notebook[title]
          }
          p {
            classs = "writer-name"
            inner = "by \(writerString)"
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

    let notebookIDExpression = Expression<String>("notebookID")
    let idExpression = Expression<String>("id")
    let userID = Expression<Int>("userID")
    let role = Expression<Int>("role")
    let title = Expression<String>("title")
    let description = Expression<String>("description")

    let db = try Connection("inklings.sqlite3");
    let notebookStories = user_stories.where(userID == user && role == Roles.writer.rawValue)
    for story in try db.prepare(notebookStories) {
      let notebookID = story[notebookIDExpression]
      let notebooks = stories.where(idExpression == notebookID)
      for notebook in try db.prepare(notebooks) {
        a {
          classs = "blocklink"
          href = "/notebook/\(notebookID)"
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

func showNotebook(_ notebookID: String, toUser user: Int) { //TODO: add user specific logic
  do {
    let user_storiesTable = Table("user_stories");
    let storiesTable = Table("stories");
    let pagesTable = Table("pages");

    let idExpression = Expression<String>("id")
    let notebookIDExpression = Expression<String>("notebookID")
    let title = Expression<String>("title")
    let description = Expression<String>("description")

    let userID = Expression<Int>("userID")
    let role = Expression<Int>("role")

    let db = try Connection("inklings.sqlite3");
    let roleQuery = user_storiesTable.where(userID == user && notebookIDExpression == notebookID)
    var userRole = 0;
    if let userStory = try db.pluck(roleQuery){
      userRole = userStory[role];
    }
    let query = storiesTable.where(idExpression == notebookID)
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
      let pages = pagesTable.where(notebookIDExpression == notebookID);
      for page in try db.prepare(pages) {
        let pageID = page[idExpression]
        a {
          classs = "blocklink"
          href = "/notebook/\(notebookID)/\(pageID)"
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

func createNotebook(title: String, description: String, userID: Int) -> String {
    do {
        let db = try Connection("inklings.sqlite3")
        
        // Generate unique id
        let id = generateUniqueNotebookID(from: title)
        
        // Insert the new story/notebook
        let insertStory = "INSERT INTO stories (id, title, description) VALUES (?, ?, ?)"
        try db.run(insertStory, id, title, description)
        
        // Create user_stories entry with writer role (1)
        let insertUserStory = "INSERT INTO user_stories (userID, notebookID, role) VALUES (?, ?, ?)"
        try db.run(insertUserStory, Int64(userID), id, Int64(Roles.writer.rawValue))
        
        return id
    } catch {
        print("Error creating notebook: \(error)")
        return "error"
    }
}

func saveComment(notebookID: String, pageID: String, userID: Int, commentText: String, selectedText: String?, startOffset: Int?, endOffset: Int?) {
  do {
    let db = try Connection("inklings.sqlite3")
    
    if let selText = selectedText, let start = startOffset, let end = endOffset {
      try db.run("INSERT INTO comments (notebookID, pageID, userID, commentText, selectedText, startOffset, endOffset) VALUES (?, ?, ?, ?, ?, ?, ?)",
        notebookID, pageID, userID, commentText, selText, start, end)
    } else {
      try db.run("INSERT INTO comments (notebookID, pageID, userID, commentText) VALUES (?, ?, ?, ?)",
        notebookID, pageID, userID, commentText)
    }
  } catch {
    // log error
  }
}

func getComments(forPage pageID: String, inNotebook notebookID: String) -> [(id: Int, userName: String, commentText: String, selectedText: String?, startOffset: Int?, endOffset: Int?, fontColor: String, fontName: String)] {
  var comments: [(id: Int, userName: String, commentText: String, selectedText: String?, startOffset: Int?, endOffset: Int?, fontColor: String, fontName: String)] = []
  do {
    let db = try Connection("inklings.sqlite3")
    let stmt = try db.prepare("SELECT c.commentID, u.name, c.commentText, c.selectedText, c.startOffset, c.endOffset, u.preferredColor, u.preferredFont FROM comments c JOIN users u ON c.userID = u.userID WHERE c.notebookID = ? AND c.pageID = ? ORDER BY c.createdAt DESC", notebookID, pageID)
    for row in stmt {
      let id = row[0] as! Int64
      let userName = row[1] as! String
      let commentText = row[2] as! String
      let selectedText = row[3] as? String
      let startOffset = row[4] as? Int64
      let endOffset = row[5] as? Int64
      let fontColor = row[6] as? String ?? "#333333"
      let fontName = row[7] as? String ?? "Handwriting"
      comments.append((id: Int(id), userName: userName, commentText: commentText, selectedText: selectedText, startOffset: startOffset.map { Int($0) }, endOffset: endOffset.map { Int($0) }, fontColor: fontColor, fontName: fontName))
    }
  } catch {
    // log error
  }
  return comments
}

func showSearchResults(query: String, forUser user: Int) {
  h2 {
    inner = "Search Results"
  }
  
  if query.isEmpty {
    p {
      inner = "Please enter a search term."
    }
    return
  }
  
  p {
    inner = "Results for: \"\(query)\""
  }
  
  do {
    let pagesTable = Table("pages")
    let storiesTable = Table("stories")
    let user_storiesTable = Table("user_stories")
    let usersTable = Table("users")
    
    let pageIDExpression = Expression<String>("id")
    let notebookIDExpression = Expression<String>("notebookID")
    let pageTitle = Expression<String>("title")
    let pageBody = Expression<String>("body")
    
    let storyTitle = Expression<String>("title")
    let storyDescription = Expression<String>("description")
    
    let userID = Expression<Int>("userID")
    let role = Expression<Int>("role")
    let userName = Expression<String>("name")
    
    let db = try Connection("inklings.sqlite3")
    
    // Get all notebook ids the user has access to
    let accessibleStories = user_storiesTable.where(userID == user)
    var notebookIDs: [String] = []
    for story in try db.prepare(accessibleStories) {
      notebookIDs.append(story[notebookIDExpression])
    }
    
    if notebookIDs.isEmpty {
      p {
        inner = "You don't have access to any notebooks."
      }
      return
    }
    
    let searchPattern = "%\(query)%"
    var storyResultCount = 0
    var pageResultCount = 0
    
    // Search stories (notebooks) first
    h3 {
      inner = "Notebooks"
    }
    
    for notebookID in notebookIDs {
      let storyQuery = storiesTable.where(
        storyIDCol == notebookID &&
        (storyTitle.like(searchPattern) || storyDescription.like(searchPattern))
      )
      
      for story in try db.prepare(storyQuery) {
        storyResultCount += 1
        
        // Find the writer(s) for this story
        let writerQuery = user_storiesTable.where(notebookIDExpression == notebookID && role == Roles.writer.rawValue)
        var writerNames: [String] = []
        for writer in try db.prepare(writerQuery) {
          let writerUserQuery = usersTable.where(userID == writer[userID])
          if let writerUser = try db.pluck(writerUserQuery) {
            writerNames.append(writerUser[userName])
          }
        }
        let writerString = writerNames.isEmpty ? "Unknown" : writerNames.joined(separator: ", ")
        
        a {
          classs = "blocklink"
          href = "/notebook/\(notebookID)"
          h2 {
            inner = story[storyTitle]
          }
          p {
            classs = "writer-name"
            inner = "by \(writerString)"
          }
          let descText = story[storyDescription]
          let snippet = String(descText.prefix(200))
          p {
            inner = snippet + (descText.count > 200 ? "..." : "")
          }
        }
      }
    }
    
    if storyResultCount == 0 {
      p {
        inner = "No matching notebooks found."
      }
    }
    
    // Search pages
    h3 {
      inner = "Pages"
    }
    
    for notebookID in notebookIDs {
      // Get the story title for display
      let storyQuery = storiesTable.where(storyIDCol == notebookID)
      guard let story = try db.pluck(storyQuery) else { continue }
      let notebookTitle = story[storyTitle]
      
      // Find the writer(s) for this story
      let writerQuery = user_storiesTable.where(notebookIDExpression == notebookID && role == Roles.writer.rawValue)
      var writerNames: [String] = []
      for writer in try db.prepare(writerQuery) {
        let writerUserQuery = usersTable.where(userID == writer[userID])
        if let writerUser = try db.pluck(writerUserQuery) {
          writerNames.append(writerUser[userName])
        }
      }
      let writerString = writerNames.isEmpty ? "Unknown" : writerNames.joined(separator: ", ")
      
      // Search pages in this story
      let pagesQuery = pagesTable.where(
        notebookIDExpression == notebookID && 
        (pageTitle.like(searchPattern) || pageBody.like(searchPattern))
      )
      
      for page in try db.prepare(pagesQuery) {
        pageResultCount += 1
        let pageID = page[pageIDExpression]
        a {
          classs = "blocklink"
          href = "/notebook/\(notebookID)/\(pageID)"
          h2 {
            inner = page[pageTitle]
          }
          p {
            classs = "writer-name"
            inner = "in \(notebookTitle) by \(writerString)"
          }
          // Show a snippet of the body
          let bodyText = page[pageBody]
          let snippet = String(bodyText.prefix(200))
          p {
            inner = snippet + (bodyText.count > 200 ? "..." : "")
          }
        }
      }
    }
    
    if pageResultCount == 0 {
      p {
        inner = "No matching pages found."
      }
    }
    
    let totalResults = storyResultCount + pageResultCount
    if totalResults > 0 {
      p {
        inner = "Found \(totalResults) result\(totalResults == 1 ? "" : "s") (\(storyResultCount) notebook\(storyResultCount == 1 ? "" : "s"), \(pageResultCount) page\(pageResultCount == 1 ? "" : "s"))."
      }
    }
  } catch {
    p {
      inner = "An error occurred while searching."
    }
  }
}

func showAccountPage(forUser userID: Int, message: String? = nil) {
    // Get user info and preferences first
    let userInfo = getUserInfo(forUser: userID)
    let currentColor = userInfo.color
    let currentFont = userInfo.font
    let userName = userInfo.name
    let customFonts = getCustomFonts(forUser: userID)
    
    div {
        idd = "accountPage"
        
        h2 { inner = "Account Settings" }
        p { inner = "Welcome, \(userName)!" }
        
        if let msg = message {
            div {
                classs = "message"
                inner = msg
            }
        }
        
        // Preview section
        div {
            idd = "previewSection"
            h3 { inner = "Preview" }
            div {
                idd = "previewBox"
                p {
                    idd = "previewText"
                    inner = "The quick brown fox jumps over the lazy dog."
                }
            }
        }
        
        // Preferences form
        form {
            action = "/account/save"
            method = "POST"
            idd = "preferencesForm"
            
            h3 { inner = "Appearance Preferences" }
            
            // Color picker
            div {
                classs = "form-group"
                label {
                    forr = "colorPicker"
                    inner = "Font Color:"
                }
                input {
                    type = "color"
                    name = "color"
                    idd = "colorPicker"
                    value = currentColor
                }
                span {
                    idd = "colorValue"
                    inner = currentColor
                }
            }
            
            // Font selector
            div {
                classs = "form-group"
                label {
                    forr = "fontSelect"
                    inner = "Font:"
                }
                select {
                    name = "font"
                    idd = "fontSelect"
                    
                    option {
                        value = "Handwriting"
                        if currentFont == "Handwriting" {
                            selected = "selected"
                        }
                        inner = "Handwriting"
                    }
                    option {
                        value = "Georgia"
                        if currentFont == "Georgia" {
                            selected = "selected"
                        }
                        inner = "Georgia"
                    }
                    option {
                        value = "Arial"
                        if currentFont == "Arial" {
                            selected = "selected"
                        }
                        inner = "Arial"
                    }
                    option {
                        value = "Courier New"
                        if currentFont == "Courier New" {
                            selected = "selected"
                        }
                        inner = "Courier New"
                    }
                    
                    // Custom fonts
                    for customFont in customFonts {
                        option {
                            value = "custom-\(customFont.fontID)"
                            if currentFont == "custom-\(customFont.fontID)" {
                                selected = "selected"
                            }
                            inner = "\(customFont.fontName) (custom)"
                        }
                    }
                }
            }
            
            input {
                type = "submit"
                value = "Save Preferences"
                classs = "save-button"
            }
        }
        
        // Font upload form
        form {
            action = "/account/upload-font"
            method = "POST"
            enctype = "multipart/form-data"
            idd = "uploadFontForm"
            
            h3 { inner = "Upload Custom Font" }
            
            div {
                classs = "form-group"
                label {
                    forr = "fontNameInput"
                    inner = "Font Name:"
                }
                input {
                    type = "text"
                    name = "fontName"
                    idd = "fontNameInput"
                    placeholder = "My Custom Font"
                }
            }
            
            div {
                classs = "form-group"
                label {
                    forr = "fontFileInput"
                    inner = "Font File (.otf, .ttf, .woff, .woff2):"
                }
                input {
                    type = "file"
                    name = "fontFile"
                    idd = "fontFileInput"
                }
            }
            
            input {
                type = "submit"
                value = "Upload Font"
                classs = "upload-button"
            }
        }
        
        // List of custom fonts
        if !customFonts.isEmpty {
            div {
                idd = "customFontsList"
                h3 { inner = "Your Custom Fonts" }
                ul {
                    for customFont in customFonts {
                        li { inner = customFont.fontName }
                    }
                }
            }
        }
        
        // Logout and reset buttons
        div {
            idd = "logoutSection"
            form {
                action = "/logout"
                method = "POST"
                classs = "logout-form"
                button {
                    type = "submit"
                    classs = "logout-button"
                    inner = "Log out"
                }
            }
            form {
                action = "/account/reset-token"
                method = "POST"
                classs = "reset-token-form"
                button {
                    type = "submit"
                    classs = "reset-token-button"
                    inner = "Reset sign-in link"
                }
            }
        }
    }
    
    // Generate @font-face rules for custom fonts
    var fontFaceCSS = ""
    for customFont in customFonts {
        fontFaceCSS += "@font-face { font-family: 'custom-\(customFont.fontID)'; src: url('/fonts/\(customFont.fileName)'); }\n"
    }
    
    // JavaScript for live preview
    script {
        inner = """
        document.addEventListener('DOMContentLoaded', function() {
            // Inject custom font-face rules
            const styleSheet = document.createElement('style');
            styleSheet.textContent = `\(fontFaceCSS)`;
            document.head.appendChild(styleSheet);
            
            const colorPicker = document.getElementById('colorPicker');
            const colorValue = document.getElementById('colorValue');
            const fontSelect = document.getElementById('fontSelect');
            const previewBox = document.getElementById('previewBox');
            const previewText = document.getElementById('previewText');
            
            // Add accept attribute to file input
            const fontFileInput = document.getElementById('fontFileInput');
            if (fontFileInput) fontFileInput.setAttribute('accept', '.otf,.ttf,.woff,.woff2');
            
            function updatePreview() {
                const color = colorPicker.value;
                const font = fontSelect.value;
                
                colorValue.textContent = color;
                previewText.style.color = color;
                previewText.style.fontFamily = font;
            }
            
            colorPicker.addEventListener('input', updatePreview);
            fontSelect.addEventListener('change', updatePreview);
            
            // Initial preview
            updatePreview();
        });
        """
    }
}

func getUserInfo(forUser userID: Int) -> (name: String, color: String, font: String) {
    do {
        let db = try Connection("inklings.sqlite3")
        let stmt = try db.prepare("SELECT name, preferredColor, preferredFont FROM users WHERE userID = ?", userID)
        for row in stmt {
            let name = row[0] as? String ?? "User"
            let color = row[1] as? String ?? "#333333"
            let font = row[2] as? String ?? "Handwriting"
            return (name: name, color: color, font: font)
        }
    } catch {
        // log error
    }
    return (name: "User", color: "#333333", font: "Handwriting")
}

func saveUserPreferences(userID: Int, color: String, font: String) {
    do {
        let db = try Connection("inklings.sqlite3")
        try db.run("UPDATE users SET preferredColor = ?, preferredFont = ? WHERE userID = ?", color, font, userID)
    } catch {
        // log error
    }
}

func saveCustomFont(userID: Int, fontName: String, fileName: String) {
    do {
        let db = try Connection("inklings.sqlite3")
        try db.run("INSERT INTO custom_fonts (userID, fontName, fileName) VALUES (?, ?, ?)", userID, fontName, fileName)
    } catch {
        // log error
    }
}

func getCustomFonts(forUser userID: Int) -> [(fontID: Int, fontName: String, fileName: String)] {
    var fonts: [(fontID: Int, fontName: String, fileName: String)] = []
    do {
        let db = try Connection("inklings.sqlite3")
        let stmt = try db.prepare("SELECT fontID, fontName, fileName FROM custom_fonts WHERE userID = ? ORDER BY fontName", userID)
        for row in stmt {
            let id = row[0] as! Int64
            let name = row[1] as! String
            let file = row[2] as! String
            fonts.append((fontID: Int(id), fontName: name, fileName: file))
        }
    } catch {
        // log error
    }
    return fonts
}

func getCustomFontByID(_ fontID: Int) -> (fontName: String, fileName: String)? {
    do {
        let db = try Connection("inklings.sqlite3")
        let stmt = try db.prepare("SELECT fontName, fileName FROM custom_fonts WHERE fontID = ?", fontID)
        for row in stmt {
            let name = row[0] as! String
            let file = row[1] as! String
            return (fontName: name, fileName: file)
        }
    } catch {
        // log error
    }
    return nil
}

func formatBodyInHTML(_ body: String) -> String {
  let paragraphs = body.components(separatedBy: "\n")
  let formattedParagraphs = paragraphs.map { p in
    return "<p class='notebook'>\(p)</p>"
  }
  return formattedParagraphs.joined()
}

func renderBodyWithInlineComments(_ bodyUnformatted: String, comments: [(id: Int, userName: String, commentText: String, selectedText: String?, startOffset: Int?, endOffset: Int?, fontColor: String, fontName: String)]) -> String {
  let body = formatBodyInHTML(bodyUnformatted)

    // Filter to only comments with selected text
    let inlineComments = comments.filter { $0.selectedText != nil && !$0.selectedText!.isEmpty }
    
    if inlineComments.isEmpty {
        return body
    }
    
    // Find actual positions for each comment by searching for selectedText
    var commentRanges: [(start: Int, end: Int, id: Int, userName: String, commentText: String, fontColor: String, fontName: String)] = []
    
    for comment in inlineComments {
        guard let selectedText = comment.selectedText else { continue }
        // Find the selected text in the body
        if let range = body.range(of: selectedText) {
            let start = body.distance(from: body.startIndex, to: range.lowerBound)
            let end = body.distance(from: body.startIndex, to: range.upperBound)
            commentRanges.append((start: start, end: end, id: comment.id, userName: comment.userName, commentText: comment.commentText, fontColor: comment.fontColor, fontName: comment.fontName))
        }
    }
    
    if commentRanges.isEmpty {
        return body
    }
    
    // Find all unique boundary points
    var boundaries = Set<Int>()
    for cr in commentRanges {
        boundaries.insert(cr.start)
        boundaries.insert(cr.end)
    }
    let sortedBoundaries = boundaries.sorted()
    
    // For each comment, determine which "lane" (vertical offset) it should use
    // Only offset when there's actual overlap with another comment
    // Sort by start position, then by end position (longer ranges first)
    let sortedCommentRanges = commentRanges.sorted { 
        if $0.start != $1.start { return $0.start < $1.start }
        return $0.end > $1.end  // Longer ranges first when same start
    }
    
    // Assign lanes: each comment gets the lowest lane not used by an overlapping comment
    var commentLane: [Int: Int] = [:]  // commentID -> lane (0 = closest to text)
    
    for cr in sortedCommentRanges {
        // Find which lanes are already used by overlapping comments
        var usedLanes = Set<Int>()
        for other in sortedCommentRanges {
            if other.id == cr.id { continue }
            // Check if they overlap
            if other.start < cr.end && other.end > cr.start {
                if let lane = commentLane[other.id] {
                    usedLanes.insert(lane)
                }
            }
        }
        // Assign the lowest unused lane
        var lane = 0
        while usedLanes.contains(lane) {
            lane += 1
        }
        commentLane[cr.id] = lane
    }
    
    // Build segments - each segment is a range with potentially multiple overlapping comments
    var segments: [(start: Int, end: Int, commentIDs: [Int])] = []
    
    for i in 0..<(sortedBoundaries.count - 1) {
        let segStart = sortedBoundaries[i]
        let segEnd = sortedBoundaries[i + 1]
        
        // Find all comment IDs that cover this segment
        var coveringIDs: [Int] = []
        for cr in commentRanges {
            if cr.start <= segStart && cr.end >= segEnd {
                coveringIDs.append(cr.id)
            }
        }
        
        segments.append((start: segStart, end: segEnd, commentIDs: coveringIDs))
    }
    
    // Create a lookup for comment details by ID
    var commentByID: [Int: (id: Int, userName: String, commentText: String, fontColor: String, fontName: String)] = [:]
    for cr in commentRanges {
        commentByID[cr.id] = (id: cr.id, userName: cr.userName, commentText: cr.commentText, fontColor: cr.fontColor, fontName: cr.fontName)
    }
    
    // Build result by processing segments in order
    var result = ""
    var currentIndex = 0
    let bodyChars = Array(body)
    var shownCommentIDs = Set<Int>()  // Track which comments we've shown
    
    for segment in segments {
        // Add any text before this segment
        if currentIndex < segment.start {
            result += String(bodyChars[currentIndex..<segment.start])
        }
        currentIndex = segment.end
        
        let segmentText = String(bodyChars[segment.start..<segment.end])
        
        if segment.commentIDs.isEmpty {
            // No comments on this segment, just add the text
            result += segmentText
        } else {
            // Build underline styles using linear-gradient backgrounds
            // Position from top using em units for consistent alignment across segments
            var gradientStyles: [String] = []
            var maxLane = 0
            for commentID in segment.commentIDs {
                if let lane = commentLane[commentID], let comment = commentByID[commentID] {
                    // Position each underline at 1.15em + (lane * 0.18em) from top
                    // Lane 0 = closest to text, only offset if there's overlap
                    let emOffset = 1.15 + (Double(lane) * 0.18)
                    gradientStyles.append("linear-gradient(\(comment.fontColor), \(comment.fontColor)) 0 \(emOffset)em / 100% 2px no-repeat")
                    if lane > maxLane {
                        maxLane = lane
                    }
                }
            }
            let background = gradientStyles.joined(separator: ", ")
            // Ensure enough padding for all underlines in this segment
            let paddingBottom = 4 + (maxLane * 4)
            
            // Check which comments end at this segment (show their text here)
            var commentsToShow: [(id: Int, userName: String, commentText: String, fontColor: String, fontName: String)] = []
            for cr in commentRanges {
                if cr.end == segment.end && !shownCommentIDs.contains(cr.id) {
                    if let comment = commentByID[cr.id] {
                        commentsToShow.append(comment)
                    }
                    shownCommentIDs.insert(cr.id)
                }
            }
            
            // Build the HTML - add data-comment-ids to track which comments this segment belongs to
            let commentIDsAttr = segment.commentIDs.map { String($0) }.joined(separator: ",")
            result += "<span class=\"comment-anchor\">"
            result += "<span class=\"commented-text\" data-comment-ids=\"\(commentIDsAttr)\" style=\"background: \(background); padding-bottom: \(paddingBottom)px;\">\(segmentText)</span>"
            
            // Add comment bubbles for comments that end here
            for comment in commentsToShow {
                let fontFamily = comment.fontName.starts(with: "custom-") ? "'\(comment.fontName)'" : comment.fontName
                result += "<span class=\"inline-comment\" data-comment-id=\"\(comment.id)\" style=\"color: \(comment.fontColor); font-family: \(fontFamily);\">\(comment.commentText) &mdash;\(comment.userName)</span>"
            }
            
            result += "</span>"
        }
    }
    
    // Add remaining text after last segment
    if currentIndex < bodyChars.count {
        result += String(bodyChars[currentIndex...])
    }
    
    return result
}

// Session Management
func createSession(forUser userID: Int) -> String {
    let sessionID = UUID().uuidString
    let expiresAt = Date().addingTimeInterval(60 * 60 * 24 * 30) // 30 days
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let expiresAtString = formatter.string(from: expiresAt)
    
    do {
        let db = try Connection("inklings.sqlite3")
        try db.run("INSERT INTO sessions (sessionID, userID, expiresAt) VALUES (?, ?, ?)", sessionID, userID, expiresAtString)
    } catch {
        // log error
    }
    return sessionID
}

func getUserFromSession(_ sessionID: String?) -> Int? {
    guard let sessionID = sessionID else { return nil }
    
    do {
        let db = try Connection("inklings.sqlite3")
        let stmt = try db.prepare("SELECT userID, expiresAt FROM sessions WHERE sessionID = ?")
        for row in stmt.bind(sessionID) {
            let expiresAtString = row[1] as! String
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let expiresAt = formatter.date(from: expiresAtString), expiresAt > Date() {
                if let id = row[0] as? Int64 {
                    return Int(id)
                }
            }
        }
    } catch {
        // log error
    }
    return nil
}

func generateID(from title: String) -> String {
    // Convert to lowercase and replace spaces/special chars with dashes
    let allowed = CharacterSet.alphanumerics
    var id = title.lowercased()
        .components(separatedBy: allowed.inverted)
        .filter { !$0.isEmpty }
        .joined(separator: "-")
    
    if id.isEmpty {
        id = "untitled"
    }
    
    return id
}

func generateUniqueNotebookID(from title: String) -> String {
    let baseID = generateID(from: title)
    
    do {
        let db = try Connection("inklings.sqlite3")
        
        // Check if base id exists
        let stmt = try db.prepare("SELECT COUNT(*) FROM stories WHERE id = ?")
        for row in stmt.bind(baseID) {
            if let count = row[0] as? Int64, count == 0 {
                return baseID
            }
        }
        
        // Add random numbers until unique
        for _ in 0..<100 {
            let number = Int.random(in: 100...999)
            let newID = "\(baseID)-\(number)"
            let checkStmt = try db.prepare("SELECT COUNT(*) FROM stories WHERE id = ?")
            for row in checkStmt.bind(newID) {
                if let count = row[0] as? Int64, count == 0 {
                    return newID
                }
            }
        }
    } catch {
        // Fall through to random
    }
    
    return "\(baseID)-\(Int.random(in: 1000...9999))"
}

func generateUniquePageID(from title: String, inNotebook notebookID: String) -> String {
    let baseID = generateID(from: title)
    
    do {
        let db = try Connection("inklings.sqlite3")
        
        // Check if base id exists in this notebook
        let stmt = try db.prepare("SELECT COUNT(*) FROM pages WHERE id = ? AND notebookID = ?")
        for row in stmt.bind(baseID, notebookID) {
            if let count = row[0] as? Int64, count == 0 {
                return baseID
            }
        }
        
        // Add random numbers until unique
        for _ in 0..<100 {
            let number = Int.random(in: 100...999)
            let newID = "\(baseID)-\(number)"
            let checkStmt = try db.prepare("SELECT COUNT(*) FROM pages WHERE id = ? AND notebookID = ?")
            for row in checkStmt.bind(newID, notebookID) {
                if let count = row[0] as? Int64, count == 0 {
                    return newID
                }
            }
        }
    } catch {
        // Fall through to random
    }
    
    return "\(baseID)-\(Int.random(in: 1000...9999))"
}

func notebookExists(_ id: String) -> Bool {
    do {
        let db = try Connection("inklings.sqlite3")
        let stmt = try db.prepare("SELECT COUNT(*) FROM stories WHERE id = ?")
        for row in stmt.bind(id) {
            if let count = row[0] as? Int64 {
                return count > 0
            }
        }
    } catch {}
    return false
}

func pageExists(_ id: String, inNotebook notebookID: String) -> Bool {
    do {
        let db = try Connection("inklings.sqlite3")
        let stmt = try db.prepare("SELECT COUNT(*) FROM pages WHERE id = ? AND notebookID = ?")
        for row in stmt.bind(id, notebookID) {
            if let count = row[0] as? Int64 {
                return count > 0
            }
        }
    } catch {}
    return false
}

func generateWhimsicalToken() -> String {
    // Load words from file
    var words: [String] = []
    if let contents = try? String(contentsOfFile: "words.txt", encoding: .utf8) {
        words = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
    }
    
    // Fallback if file is empty or missing
    if words.count < 4 {
        return UUID().uuidString
    }
    
    // Pick 4 random words
    var selectedWords: [String] = []
    for _ in 0..<4 {
        let index = Int.random(in: 0..<words.count)
        selectedWords.append(words[index])
    }
    
    // Append 3-digit number
    let number = Int.random(in: 100...999)
    
    return selectedWords.joined(separator: "-") + "-\(number)"
}

func getUserByMagicToken(_ token: String) -> Int? {
    do {
        let db = try Connection("inklings.sqlite3")
        let stmt = try db.prepare("SELECT userID FROM users WHERE magicToken = ?")
        for row in stmt.bind(token) {
            if let id = row[0] as? Int64 {
                return Int(id)
            }
        }
    } catch {
        // log error
    }
    return nil
}

func getSessionCookie(from request: HttpRequest) -> String? {
    for header in request.headers {
        if header.0.lowercased() == "cookie" {
            let cookies = header.1.split(separator: ";")
            for cookie in cookies {
                let parts = cookie.trimmingCharacters(in: .whitespaces).split(separator: "=", maxSplits: 1)
                if parts.count == 2 && parts[0] == "session" {
                    return String(parts[1])
                }
            }
        }
    }
    return nil
}

func getCurrentUser(from request: HttpRequest) -> Int? {
    let sessionID = getSessionCookie(from: request)
    return getUserFromSession(sessionID)
}

func getUserPreferences(forUser userID: Int) -> (color: String, font: String) {
    do {
        let db = try Connection("inklings.sqlite3")
        let stmt = try db.prepare("SELECT preferredColor, preferredFont FROM users WHERE userID = ?", userID)
        for row in stmt {
            let color = row[0] as? String ?? "#333333"
            let font = row[1] as? String ?? "Handwriting"
            return (color: color, font: font)
        }
    } catch {
        // log error
    }
    return (color: "#333333", font: "Handwriting")
}
