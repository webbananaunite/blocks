//
//  String+.swift
//  blocks
//
//  Created by よういち on 2023/11/03.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public extension String {
    var jsonToDictionary: [String: String]? {
        Log(self)
        do {
            if let jsonAsData = self.utf8DecodedData {
                Log(jsonAsData.utf8String)
                if let jsonAsDictionary = try JSONSerialization.jsonObject(with: jsonAsData, options: .allowFragments) as? [String: String] {
                    Log(jsonAsDictionary)
                    return jsonAsDictionary
                }
            }
        } catch {
            Log("Error Fetching Json Data:\(error)")
        }
        return nil
    }
    
    var jsonToAnyDictionary: [String: Any]? {
        Log(self)
        do {
            if let jsonAsData = self.utf8DecodedData {
                Log()
                if let jsonAsDictionary = try JSONSerialization.jsonObject(with: jsonAsData, options: .allowFragments) as? [String: Any] {
                    Log(jsonAsDictionary)
                    return jsonAsDictionary
                }
            }
        } catch {
            Log("Error Fetching Json Data:\(error)")
        }
        Log()
        return nil
    }
    
    var jsonToDictionaryArray: [[String : Any]]? {
        Log(self)
        do {
            if let jsonAsData = self.utf8DecodedData {
                Log()
                if let jsonAsDictionary = try JSONSerialization.jsonObject(with: jsonAsData, options: .allowFragments) as? [[String: Any]] {
                    Log(jsonAsDictionary)
                    return jsonAsDictionary
                }
            }
        } catch {
            Log("Error Fetching Json Data:\(error)")
        }
        Log()
        return nil
    }
}
