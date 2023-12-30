//
//  HashedData.swift
//  blocks
//
//  Created by よういち on 2023/12/19.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import CryptoKit

public protocol HashedData {
    static var hashedMethod: String {
        get
    }
    static var hashDataBits: Int {
        get
    }
    static var hashDataBytes: Int {
        get
    }
    func validHash() -> Bool
    var hashedStringAsHex: HashedString? {
        get
    }
    var hashedData: HashedData? {
        get
    }
    var toData: Data? {
        get
    }
}

extension Data: HashedData {
    public static var hashedMethod: String = "SHA512"
    public static var hashDataBits: Int  = 512
    public static var hashDataBytes: Int = 64
    public func validHash() -> Bool {
        self.count == Self.hashDataBytes
    }
    /*
     SHA512 to HexaDecimal chars
     ascii 128 chars (Hex: 4 bit == ASCII a char)
     */
    public var hashedStringAsHex: HashedString? {
        let sha512digest = SHA512.hash(data: self)
        Log(sha512digest)
        let hexString = sha512digest.compactMap {
            String(format: "%02x", $0)
        }.joined()
        if hexString.count == String.hashStringChars {
            return hexString
        } else {
            return nil
        }
    }
    public var hashedData: HashedData? {
        if let hashedData = self.hashedStringAsHex?.toData {
            return hashedData
        }
        return nil
    }
    public var toData: Data? {
        self
    }
}
