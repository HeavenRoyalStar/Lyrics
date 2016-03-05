//
//  LyricsEditWindowController.swift
//  Lyrics
//
//  Created by Eru on 15/11/19.
//  Copyright © 2015年 Eru. All rights reserved.
//

import Cocoa

class LyricsEditWindowController: NSWindowController {
    
    static let sharedController = LyricsEditWindowController()
    
    @IBOutlet var textView: NSTextView!
    @IBOutlet var boxView: NSBox!
    @IBOutlet var leftBracket: NSTextField!
    @IBOutlet var rightBracket: NSTextField!
    @IBOutlet var actionType: NSPopUpButton!
    
    private var currentSongID: String!
    private var currentTitle: String!
    private var currentArtist: String!
    
    private var hideOptionConstraint: NSLayoutConstraint!
    private var showOptionConstraint: NSLayoutConstraint!
    
    convenience init() {
        self.init(windowNibName:"LyricsEditWindow")
        self.window?.level = Int(CGWindowLevelForKey(.NormalWindowLevelKey))
        textView.textColor = NSColor.whiteColor()
        textView.font = NSFont(name: "Helvetica-Bold", size: 14)
        
        hideOptionConstraint = NSLayoutConstraint(item: boxView, attribute: .Height, relatedBy: NSLayoutRelation.LessThanOrEqual, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 0)
        showOptionConstraint = NSLayoutConstraint(item: boxView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 24)
        boxView.addConstraint(hideOptionConstraint)
        self.window?.makeFirstResponder(textView)
    }
    
    func setLyricsContents(contents: String, songID: String, songTitle: String, andArtist artist: String) {
        currentSongID = songID
        currentTitle = songTitle
        currentArtist = artist
        textView.string = contents
    }
    
    @IBAction func showAndHideOptions(sender: AnyObject) {
        if (sender as! NSButton).state == NSOnState {
            boxView.removeConstraint(hideOptionConstraint)
            boxView.addConstraint(showOptionConstraint)
        }
        else {
            boxView.removeConstraint(showOptionConstraint)
            boxView.addConstraint(hideOptionConstraint)
        }
    }
    
    @IBAction func applyOperation(sender: AnyObject) {
        if leftBracket.stringValue.characters.count != 1 || rightBracket.stringValue.characters.count != 1 {
            return
        }
        var lyricsLines = [LyricsLineModel]()
        var newLyrics = String()
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: "\\[\\d+:\\d+.\\d+\\]|\\[\\d+:\\d+\\]", options: [])
        } catch let theError as NSError {
            NSLog("%@", theError.localizedDescription)
            return
        }
        let newLineCharSet: NSCharacterSet = NSCharacterSet.newlineCharacterSet()
        let lrcParagraphs: [String] = textView.string!.componentsSeparatedByCharactersInSet(newLineCharSet)
        
        for str in lrcParagraphs {
            let timeTagsMatched: [NSTextCheckingResult] = regex.matchesInString(str, options: [], range: NSMakeRange(0, str.characters.count))
            if timeTagsMatched.count > 0 {
                let index: Int = timeTagsMatched.last!.range.location + timeTagsMatched.last!.range.length
                var lyricsSentence: String = str.substringFromIndex(str.startIndex.advancedBy(index))
                lyricsSentence = operationToString(lyricsSentence)
                for result in timeTagsMatched {
                    let matchedRange: NSRange = result.range
                    let lrcLine: LyricsLineModel = LyricsLineModel()
                    lrcLine.lyricsSentence = lyricsSentence
                    lrcLine.setMsecPositionWithTimeTag((str as NSString).substringWithRange(matchedRange))
                    let currentCount: Int = lyricsLines.count
                    var j: Int
                    for j=0; j<currentCount; ++j {
                        if lrcLine.msecPosition < lyricsLines[j].msecPosition {
                            lyricsLines.insert(lrcLine, atIndex: j)
                            break
                        }
                    }
                    if j == currentCount {
                        lyricsLines.append(lrcLine)
                    }
                }
            }
            else {
                if str.stringByReplacingOccurrencesOfString(" ", withString: "") != "" {
                    newLyrics.appendContentsOf(str + "\n")
                }
            }
        }
        for lrc in lyricsLines {
            newLyrics.appendContentsOf(lrc.timeTag + lrc.lyricsSentence + "\n")
        }
        self.textView.string = newLyrics
    }
    
    @IBAction func cancelAction(sender: AnyObject) {
        self.window?.orderOut(nil)
    }
    
    @IBAction func okAction(sender: AnyObject) {
        let dic: [String:AnyObject] = ["SongID":currentSongID, "SongTitle":currentTitle, "SongArtist":currentArtist]
        NSNotificationCenter.defaultCenter().postNotificationName(LyricsUserEditLyricsNotification, object: nil, userInfo: dic)
        self.window?.orderOut(nil)
    }
    
    //MARK: - Other
    
    private func operationToString (str: String) -> String {
        let rightBracketIdx = getRightBracketIndex(str)
        if rightBracketIdx == -1 {
            return str
        }
        let leftBracketIdx = getLeftBracketIndex(str, lastCharacterIndex: rightBracketIdx)
        if leftBracketIdx == -1 {
            return str
        }
        if actionType.indexOfSelectedItem == 0 {
            return (str as NSString).substringToIndex(leftBracketIdx)
        }
        else if actionType.indexOfSelectedItem == 1 {
            let loc = leftBracketIdx + 1
            let len = rightBracketIdx - loc
            return (str as NSString).substringWithRange(NSMakeRange(loc, len))
        }
        else {
            let loc = leftBracketIdx + 1
            let len = rightBracketIdx - loc
            let formmerPart = (str as NSString).substringToIndex(leftBracketIdx)
            let latterPart = (str as NSString).substringWithRange(NSMakeRange(loc, len))
            return latterPart + leftBracket.stringValue + formmerPart + rightBracket.stringValue
        }
    }
    
    private func getRightBracketIndex(str: NSString) -> Int {
        var index: Int = str.length - 1
        while index > -1 {
            let char: String = str.substringWithRange(NSMakeRange(index, 1))
            if char == " " {
                index--
                continue
            }
            else if char == rightBracket.stringValue {
                return index
            }
            else {
                return -1
            }
        }
        return -1
    }
    
    private func getLeftBracketIndex(str: NSString, lastCharacterIndex theIndex: Int) -> Int {
        var stack: [Int] = Array()
        var index: Int = 0
        while index < theIndex {
            let char: String = str.substringWithRange(NSMakeRange(index, 1))
            if char == leftBracket.stringValue {
                stack.append(index)
            }
            else if char == rightBracket.stringValue {
                if stack.count == 0 {
                    return -1
                }
                stack.removeLast()
            }
            index++
        }
        if stack.count == 1 {
            return stack.first!
        } else {
            return -1
        }
    }

}
