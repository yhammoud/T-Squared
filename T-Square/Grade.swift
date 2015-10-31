//
//  Grade.swift
//  T-Square
//
//  Created by Cal on 9/22/15.
//  Copyright © 2015 Georgia Tech. All rights reserved.
//

import Foundation

protocol Scored {
    
    var name: String { get }
    var score: Double? { get }
    var scoreString: String { get }
    var weight: Double? { get }
    var isArtificial: Bool { get }
    
    func representAsString() -> String
    
}

func scorefromString(string: String) -> Scored? {
    if string.hasPrefix("GRADE") {
        let splits = string.componentsSeparatedByString("~")
        if splits.count != 4 { return nil }
        let grade = Grade(name: splits[2], score: splits[3], weight: nil, comment: nil, isArtificial: true)
        grade.owningGroup = splits[1]
        return grade
    }
    if string.hasPrefix("GROUP") {
        let splits = string.componentsSeparatedByString("~")
        if splits.count != 3 { return nil }
        return GradeGroup(name: splits[1], weight: "\(splits[2])%", isArtificial: true)
    }
    return nil
}

class Grade : Scored, CustomStringConvertible {
    
    let name: String
    let score: Double?
    let scoreString: String
    let weight: Double?
    let comment: String?
    
    var isArtificial: Bool = false
    var owningGroup: String?
    
    var contributesToAverage: Bool = true
    
    init(name: String, score: String?, weight: String?, comment: String?, isArtificial: Bool = false) {
        self.name = name
        self.comment = comment
        self.scoreString = score?.cleansed() ?? "—"
        self.isArtificial = isArtificial
        
        if scoreString.hasPrefix("(") { contributesToAverage = false }
        let scoreToParse = scoreString.stringByReplacingOccurrencesOfString("(", withString: "").stringByReplacingOccurrencesOfString(")", withString: "")
        
        //parse score
        if scoreToParse.hasSuffix("%") {
            if let percentScore = scoreToParse.percentStringAsDouble() {
                self.score = percentScore
                self.weight = 100.0
                return
            }
        }
        else if scoreToParse.containsString("/") {
            let splits = scoreToParse.componentsSeparatedByString("/")
            if splits.count >= 2 {
                if let points = splits[0].asDouble(), let total = splits[1].asDouble() {
                    self.score = points / total
                    self.weight = total
                    return
                }
            }
        }
        
        self.score = nil
        self.contributesToAverage = false
        self.weight = nil
    }
    
    var description: String {
        return "\(name)(score=\(scoreString))"
    }
    
    func representAsString() -> String {
        return "GRADE~\(owningGroup ?? "")~\(name)~\(scoreString)"
    }
    
}

class GradeGroup : Scored, CustomStringConvertible {
    
    let name: String
    let weight: Double?
    var scores: [Scored] = []
    let isArtificial: Bool
    
    init(name: String, weight: String?, isArtificial: Bool = false) {
        self.name = name
        self.isArtificial = isArtificial
        if let weightString = weight?.cleansed() where weightString.hasSuffix("%") {
            if let percent = weightString.percentStringAsDouble() {
                self.weight = percent * 100.0
                return
            }
        }
        self.weight = nil
    }
    
    init(name: String, weight: Double?, isArtificial: Bool = false) {
        self.name = name
        self.weight = weight
        self.isArtificial = isArtificial
    }
    
    var useAllSubscores = false {
        didSet {
            for score in scores {
                if let group = score as? GradeGroup {
                    group.useAllSubscores = self.useAllSubscores
                }
            }
        }
    }
    
    var score: Double? {
        if scores.count == 0 { return nil }
        var totalPoints = 0.0
        var totalWeight = 0.0
        
        for score in scores {
            if (score as? Grade)?.contributesToAverage == false && self.useAllSubscores == false { continue }
            if let points = score.score, let weight = score.weight {
                totalPoints += (points * weight)
                totalWeight += weight
            }
        }
        
        if totalWeight == 0.0 { return nil }
        return totalPoints / totalWeight
    }
    
    var scoreString: String {
        if let score = score {
            let rounded = Double(Int(score * 1000)) / 10.0
            var roundedString = "\(rounded)"
            if roundedString.hasSuffix(".0") {
                roundedString = (roundedString as NSString).substringToIndex(roundedString.length - 2)
            }
            return "\(roundedString)%"
        }
        return "-"
    }
    
    var description: String {
        return "\(name) [total score = \(self.scoreString)]\(scores)"
    }
    
    var flattened: [Scored] {
        var flattenedArray: [Scored] = []
        
        for score in scores {
            if let group = score as? GradeGroup {
                flattenedArray.append(group)
                if group.scores.count == 0 {
                    flattenedArray.append(Grade(name: "Nothing here yet.", score: "", weight: nil, comment: nil))
                }
                else {
                    flattenedArray.appendContentsOf(group.flattened)
                }
                flattenedArray.append(Grade(name: "", score: "", weight: nil, comment: nil))
            }
            else {
                flattenedArray.append(score)
                if let grade = score as? Grade, let comment = grade.comment?.cleansed() where comment != "" && comment != "from Assignments" && comment != "from Tests & Quizzes" {
                    flattenedArray.append(Grade(name: comment, score: "COMMENT_PLACEHOLDER", weight: nil, comment: nil))
                }
            }
        }
        return flattenedArray
    }
    
    func representAsString() -> String {
        return "GROUP~\(name)~\(weight ?? 0.0)"
    }
    
}