//
//  ClassDelegate.swift
//  T-Squared for Georgia Tech
//
//  Created by Cal on 9/3/15.
//  Copyright © 2015 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit

class ClassDelegate : NSObject, StackableTableDelegate {
    
    //MARK: - Table View Delegate methods
    
    let controller: ClassesViewController
    let displayClass: Class
    
    init(controller: ClassesViewController, displayClass: Class) {
        self.controller = controller
        self.displayClass = displayClass
        displayClass.markClassOpened()
    }
    
    static let hideSeparator: (UITableViewCell, Class) -> () = { cell, _ in
        cell.hideSeparator()
    }
    
    static func titleDisplayWithText(text: String, hideSeparator: Bool = false) -> (UITableViewCell, Class) -> () {
        return { cell, displayClass in
            if let cell = cell as? TitleCell {
                cell.decorate(text)
            }
            
            (hideSeparator ? cell.hideSeparator : cell.showSeparator)()
        }
    }
    
    var cells: [(identifier: String, onDisplay: (UITableViewCell, Class) -> (), onTap: ((ClassesViewController, Class) -> ())? )] = [
    
        (identifier: "back", onDisplay: hideSeparator, onTap: nil),
        (identifier: "classTitleWithIcon", onDisplay: { cell, displayClass in
            if let cell = cell as? ClassNameCell {
                cell.decorate(displayClass)
                cell.hideSeparator()
            }
        }, onTap: nil),
        
        (identifier: "blank", onDisplay: hideSeparator, onTap: nil),
        (identifier: "standardTitle", onDisplay: ClassDelegate.titleDisplayWithText("Assignments"), onTap: { controller, displayClass in
            
            //load assignments
            let delegate = AssignmentsDelegate(owningClass: displayClass, controller: controller)
            delegate.loadDataAndPushInController(controller)
            
        }),
        
        
        (identifier: "standardTitle", onDisplay: ClassDelegate.titleDisplayWithText("Resources"), onTap: { controller, displayClass in
            
            //load root resources
            if let rootFolder = TSAuthenticatedReader.getResourceRootForClass(displayClass) {
                let delegate = ResourcesDelegate(controller: controller, inFolder: rootFolder)
                delegate.loadDataAndPushInController(controller)
            }
            else {
                let alert = UIAlertController(title: "No Resources Folder", message: "This class does not have a Resources folder.", preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                controller.presentViewController(alert, animated: true, completion: nil)
            }
            
        }),
        
        (identifier: "standardTitle", onDisplay: ClassDelegate.titleDisplayWithText("Gradebook"), onTap: { controller, displayClass in
            
            let delegate = GradebookDelegate(forClass: displayClass, controller: controller)
            delegate.loadDataAndPushInController(controller)
            
        }),
        
        (identifier: "standardTitle", onDisplay: ClassDelegate.titleDisplayWithText("Syllabus"), onTap: { controller, displayClass in
            
            controller.setActivityIndicatorVisible(true)
            dispatch_async(TSNetworkQueue) {
                let (syllabusLink, documentLink) = TSAuthenticatedReader.getSyllabusURLForClass(displayClass)
                sync {
                    if let documentLink = documentLink {
                        
                        var fixedLink = documentLink
                        if !fixedLink.containsString("http") {
                            fixedLink = "https://files.t-square.gatech.edu\(documentLink)"
                        }
                        
                        if let url = NSURL(string: fixedLink) {
                            controller.presentDocumentFromURL(url, name: "Syllabus")
                            return
                        }
                        
                    }
                    
                    if let syllabusLink = syllabusLink {
                        controller.openLinkInWebView(syllabusLink, title: "Syllabus")
                        return
                    }
                    
                    //no return, meaning none of the expecting links worked
                    controller.setActivityIndicatorVisible(false)
                    let alert = UIAlertController(title: "Syllabus not available", message: "The syllabus got away from us somehow. It looks like there isn't one posted.", preferredStyle: .Alert)
                    alert.addAction(UIAlertAction(title: "ok", style: UIAlertActionStyle.Default, handler: nil))
                    controller.presentViewController(alert, animated: true, completion: nil)

                }
            }
            
        }),
        
        (identifier: "standardTitle", onDisplay: ClassDelegate.titleDisplayWithText("View More Options", hideSeparator: true), onTap: { controller, displayClass in
            
            var link = displayClass.link
            if iPad() {
                link += "?force.classic=yes"
            }
            controller.openLinkInWebView(link, title: displayClass.name)
            
        }),
        (identifier: "blank", onDisplay: hideSeparator, onTap: nil)
        
    ]
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return cells.count
        }
        else if section == 1 {
            let count = displayClass.announcements.count
            return max(2, count + 1 + (count == 10 ? 1 : 0))
        }
        else { return 0 }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let (identifier, onDisplay, _) = cells[indexPath.item]
            let cell = tableView.dequeueReusableCellWithIdentifier(identifier)!
            onDisplay(cell, displayClass)
            return cell
        }
        
        if indexPath.section == 1 {
            if indexPath.item == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("title") as! TitleCell
                cell.decorate("Announcements")
                return cell
            }
            
            if indexPath.item == 1 && displayClass.announcements.count == 0 {
                let cell = tableView.dequeueReusableCellWithIdentifier("message") as! TitleCell
                cell.decorate(controller.loadingAnnouncements ? "Loading Announcements..." : "Nothing here yet.")
                return cell
            }
            
            let index = indexPath.item - 1
            
            if index >= displayClass.announcements.count { //Load More Announcements
                let cell = tableView.dequeueReusableCellWithIdentifier("subtitle") as! TitleCell
                cell.decorate("Load more announcements...")
                cell.backgroundColor = UIColor(red: 0.43, green: 0.69, blue: 1.0, alpha: 0.4)
                return cell
            }
            
            let cell = tableView.dequeueReusableCellWithIdentifier("announcement") as! AnnouncementCell
            cell.decorate(displayClass.announcements[index])
            return cell
        }
        
        return tableView.dequeueReusableCellWithIdentifier("announcementTitle")!
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 0 {
            let identifier = cells[indexPath.item].identifier
            if identifier == "blank" { return 15.0 }
            if identifier == "classTitleWithIcon" { return 80.0 }
            if identifier == "announcementTitle" { return 60.0 }
        }
        if indexPath.section == 1 {
            if indexPath.item == 0 { return 40.0 }
            else { return 60.0 }
        }
        return 50.0
    }
    
    //MARK: - Stackable Delegate methods
    
    func loadData() {
        controller.loadingAnnouncements = true
        dispatch_async(TSNetworkQueue) {
            self.displayClass.announcements = TSAuthenticatedReader.getAnnouncementsForClass(self.displayClass)
            sync {
                self.controller.loadingAnnouncements = false
                self.controller.reloadTable()
            }
        }
        
    }
    
    func loadCachedData() {
        return
    }
    
    func isFirstLoad() -> Bool {
        return false
    }
    
    func canHighlightCell(index: NSIndexPath) -> Bool {
        return index.section == 0
               ? cells[index.item].onTap != nil
               : index.item != 0
    }
    
    func processSelectedCell(index: NSIndexPath) {
        //announcements
        if index.section == 1 {
            if index.item == 0 { return }
            if index.item == 1 && displayClass.announcements.count == 0 { return }
            
            if index.item - 1 >= displayClass.announcements.count {
                //load more announcements
                controller.setActivityIndicatorVisible(true)
                dispatch_async(TSNetworkQueue) {
                    let allAnnouncements = TSAuthenticatedReader.getAnnouncementsForClass(self.displayClass, loadAll: true)
                    self.displayClass.announcements = allAnnouncements
                    sync {
                        self.controller.reloadTable()
                        self.controller.setActivityIndicatorVisible(false)
                    }
                }
                return
            }
            
            let announcement = displayClass.announcements[index.item - 1]
            let delegate = AnnouncementDelegate(announcement: announcement, controller: controller)
            delegate.loadDataAndPushInController(controller)
        }
        
        //assignments
        if index.section == 0 {
            if let onTap = cells[index.item].onTap {
                onTap(controller, displayClass)
            }
        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: false)
        delay(0.5) {
            NSNotificationCenter.defaultCenter().postNotificationName(TSSetTouchDelegateEnabledNotification, object: true)
        }
    }
    
    func animateSelection(cell: UITableViewCell, indexPath: NSIndexPath, selected: Bool) {
        let background: UIColor
        if indexPath.section == 0 {
            background = UIColor(white: 1.0, alpha: selected ? 0.3 : 0.0)
        }
        else { //if section == 1
            if indexPath.item == 0 { return }
            if indexPath.item == 1 && displayClass.announcements.count == 0 { return }
            if selected {
                background = UIColor(hue: 0.5833333333, saturation: 1.0, brightness: 1.0, alpha: 0.1)
            }
            else {
                background = UIColor(red: 0.43, green: 0.69, blue: 1.0, alpha: 0.4)
            }
        }
        
        UIView.animateWithDuration(0.3, animations: {
            cell.backgroundColor = background
        })
    }
    
}