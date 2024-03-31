//
//  Time.swift
//  blocks
//
//  Created by よういち on 2021/09/05.
//  Copyright © 2021 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public struct Time {
    /*
     Date to UTC String in MilliSeconds
        2020-12-31T12:34:56.123+09:00
     */
    public static var utcTimeString: String {
        get {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions.insert(.withFractionalSeconds)//ms

            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            let utcTimeString = dateFormatter.string(from: Date())
            Log(utcTimeString)  //2022-09-02T08:38:42.940Z
            return utcTimeString
        }
    }
}
