//
//  HashedString.swift
//  blocks
//
//  Created by よういち on 2023/12/19.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public protocol HashedString {
    static var hashedMethod: String {
        get
    }
    static var hashStringChars: Int {
        get
    }
    var hashedStringAsHex: HashedString? {
        get
    }
    var toString: String {
        get
    }
    func equal(_ value: HashedString) -> Bool
    var toData: Data? {
        get
    }
}

extension String: HashedString {
    public static var hashedMethod: String = "SHA512(HexaDecimal)"
    public static var hashStringChars: Int = 128
    public var hashedStringAsHex: HashedString? {
        if let data = self.utf8DecodedData {
            return data.hashedStringAsHex
        }
        return nil
    }
    public var toString: String {
        self
    }
    public func equal(_ value: HashedString) -> Bool {
        self.toString == value.toString
    }
    public var toData: Data? {
        self.hexadecimalDecodedData
    }
}
