//
//  Dictionary+.swift
//  blocks
//
//  Created by よういち on 2023/11/03.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public extension [String: String] {
    var dictionaryToJsonString: String? {
        if let dataAsJson = try? JSONSerialization.data(withJSONObject: self, options: [.sortedKeys]), let textAsJsonFormatted = dataAsJson.utf8String {
            return textAsJsonFormatted
        }
        return nil
    }
    
    var sortedTuple: [(String, String)] {
        self.sorted(by: <)
    }
}

public extension [String: Any] {
    var dictionaryToJsonString: String? {
        if let dataAsJson = try? JSONSerialization.data(withJSONObject: self, options: [.sortedKeys]), let textAsJsonFormatted = dataAsJson.utf8String {
            return textAsJsonFormatted
        }
        return nil
    }
}

public extension [[String : Any]] {
    var dictionarysToJsonString: String? {
        if let dataAsJson = try? JSONSerialization.data(withJSONObject: self, options: [.sortedKeys]), let textAsJsonFormatted = dataAsJson.utf8String {
            return textAsJsonFormatted
        }
        return nil
    }
}
