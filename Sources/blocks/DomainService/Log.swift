//
//  Log.swift
//  blocks
//
//  Created by よういち on 2020/06/19.
//  Copyright © 2020 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import UIKit

public func Log(_ object: Any = "", functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
    #if DEBUG
    let className = (fileName as NSString).lastPathComponent
    /*
     Disable Logging in following Classes.
     */
    if className == "Streaming.swift" {
        return
    }
    if className == "Stream+.swift" {
        return
    }
    if className == "Data+.swift" {
        return
    }
    if className == "Queue.swift" {
        return
    }
    if className == "Time.swift" {
        return
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    let dateString = formatter.string(from: Date())
    print("\(dateString) \(className) \(functionName) l.\(lineNumber) \(object)\n")
    #endif
}

public func LogEssential(_ object: Any = "", functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
    #if DEBUG
    let className = (fileName as NSString).lastPathComponent
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    let dateString = formatter.string(from: Date())
    print("\(dateString) \(className) \(functionName) l.\(lineNumber) \(object) ***\n")
    #endif
}

public func LogCommunicate(_ object: Any = "", functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
    #if DEBUG
    let className = (fileName as NSString).lastPathComponent
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    let dateString = formatter.string(from: Date())
    print("\(dateString) \(className) \(functionName) l.\(lineNumber) \(object) ***\n")
    #endif
}

public func Dump(_ object: Any = "", functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
//    #if true
//    let className = (fileName as NSString).lastPathComponent
//    let formatter = DateFormatter()
//    formatter.dateFormat = "HH:mm:ss"
//    let dateString = formatter.string(from: Date())
//    print("\(dateString) \(className) \(functionName) l.\(lineNumber)\n")
////    print((object as! Data).count)
//    if object is Data {
//        dump((object as! NSData))
//    } else {
//        dump(object)
//    }
//    #endif
}

public func DumpEssential(_ object: Any = "", functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
    #if false
    let className = (fileName as NSString).lastPathComponent
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    let dateString = formatter.string(from: Date())
    print("DE \(dateString) \(className) \(functionName) l.\(lineNumber)\n")
//    print((object as! Data).count)
    if object is Data {
        dump((object as! NSData))
    } else {
        dump(object)
    }
    #endif
}
