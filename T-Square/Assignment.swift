//
//  Assignment.swift
//  T-Square
//
//  Created by Cal on 9/12/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation
import Kanna

class Assignment {
    
    let name: String
    let link: String
    let rawDueDateString: String
    let dueDate: NSDate?
    let completed: Bool
    let owningClass: Class
    
    var message: String?
    var attachments: [Attachment]?
    var submissions: [Attachment]?
    var feedback: String?
    
    init(name: String, link: String, dueDate: String, completed: Bool, inClass owningClass: Class) {
        self.owningClass = owningClass
        self.name = name
        self.link = link
        self.rawDueDateString = dueDate
        self.completed = completed
        self.dueDate = dueDate.dateWithTSquareFormat()
    }
    
    func loadMessage(attempt attempt: Int = 0) {
        if message != nil { return } //already loaded
        
        if let page = HttpClient.contentsOfPage(self.link) {
            
            if !page.toHTML!.containsString("<div class=\"textPanel\">") {
                print("reloading assignment")
                if attempt > 10 {
                    self.message = "Could not load message for assignment."
                }
                self.loadMessage(attempt: attempt + 1)
            }
            else {
                
                //load attachments if present
                //split into submissions and attachments
                let splits = page.toHTML!.componentsSeparatedByString("<h5>Submitted Attachments</h5>")
                let attachmentsPage = HTML(html: splits[0], encoding: NSUTF8StringEncoding)!
                let submissionsPage: HTMLDocument? = splits.count != 1 ? HTML(html: splits[1], encoding: NSUTF8StringEncoding)! : nil
                
                //load main message
                var message: String = ""
                
                for divTag in attachmentsPage.css("div") {
                    if divTag["class"] != "textPanel" { continue }
                    message += divTag.textWithLineBreaks
                }
                
                if message == "" {
                    message = "No message content."
                }
                
                self.message = message.withNoTrailingWhitespace()
                
                //load attachments
                for link in attachmentsPage.css("a, link") {
                    let linkURL = link["href"] ?? ""
                    if linkURL.containsString("/attachment/") {
                        let attachment = Attachment(link: linkURL, fileName: link.text?.cleansed() ?? "Attached file")
                        if self.attachments == nil { self.attachments = [] }
                        self.attachments!.append(attachment)
                    }
                }
                
                //load submissions
                if let submissionsPage = submissionsPage {
                    for link in submissionsPage.css("a, link") {
                        let linkURL = link["href"] ?? ""
                        if linkURL.containsString("/attachment/") {
                            let attachment = Attachment(link: linkURL, fileName: link.text?.cleansed() ?? "Attached file")
                            if self.submissions == nil { self.submissions = [] }
                            self.submissions!.append(attachment)
                        }
                    }
                    
                    //load submission comments
                    var feedback: String = ""
                    
                    for divTag in submissionsPage.css("div") {
                        if divTag["class"] != "textPanel" { continue }
                        print(divTag.textWithLineBreaks)
                        if divTag["class"] != "textPanel" { continue }
                        feedback += divTag.textWithLineBreaks
                    }
                    
                    if feedback != "" {
                        self.feedback = feedback.withNoTrailingWhitespace()
                    }
                    
                }
                
            }
        }
    }
    
}