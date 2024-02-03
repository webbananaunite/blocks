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
    
    /*
     Caution:
     This Function Comsume very large Time.
     
     "nonce":"ffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010"
     ↓
     "f{10}0{20}10"
     */
    var compressedHexDecimalString: String {
        Log(self)
        var preCharacter: Character?
        var serialCount = 1
        let compressedString = self.enumerated().reduce("") {
            var addCharacter: String = ""
            if preCharacter == $1.element {
                //Detected Appere Same Char
                serialCount += 1
            } else {
                //Detected Appere Defferent Char
                var compressedCharacter = ""
                if serialCount > 1, let serialCharacter = preCharacter {
                    //There Same Character Series
                    compressedCharacter = "{\(serialCount)}"
                }
                addCharacter = compressedCharacter + String($1.element)
                serialCount = 1
            }
            preCharacter = $1.element
            if addCharacter == "" && $1.offset >= self.count - 1 {
                //Last Character is Same Previous.
                let compressedCharacter = "{\(serialCount)}"
                addCharacter = compressedCharacter
            }
            return $0 + addCharacter
        }
        Log("Compressed Nonce: \(compressedString)")
        return compressedString
    }

    /*
     "f{10}0{20}10"
     ↓
     "nonce":"ffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010"
     
     
     f{26}0{88}10 ***
     ↓
     14:27:36 String+.swift decomressedData l.128 Decompressed Nonce: f666666666666666666666666660888888888888888888888888888888888888888888888888888888888888888888888888888888888888888810 ***
     6が26個になっている
     ↑これが復号できていない
     
     */
    var decomressedData: Data? {
        Log(self)
        var innerSerialCounter = false
        var serialCountValue = ""
        var preCharacter: Character?
        let decompressedString = self.enumerated().reduce("") {
            var addCharacter: String = ""
            if $1.element == "{" {
                innerSerialCounter = true
                serialCountValue = ""
            } else if $1.element == "}" {
                innerSerialCounter = false
                if let serialCountValueAsInt = Int(serialCountValue), serialCountValueAsInt - 1 > 0, let preCharacter = preCharacter {
                    addCharacter = String(repeating: preCharacter, count: serialCountValueAsInt - 1)
                }
            } else {
                if innerSerialCounter {
                    serialCountValue += String($1.element)
                } else {
                    addCharacter = String($1.element)
                    preCharacter = $1.element
                }
            }
            return $0 + addCharacter
        }
        Log("Decompressed Nonce: \(decompressedString)")
        return decompressedString.hexadecimalDecodedData
    }
}
