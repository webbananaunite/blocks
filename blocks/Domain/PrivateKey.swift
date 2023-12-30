//
//  PrivateKey.swift
//  blocks
//
//  Created by よういち on 2023/12/20.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public protocol PrivateKey {
    static var privateKeyMethod: String {
        get
    }
    static var privateKeyBits: Int {
        get
    }
    static var privateKeyBytes: Int {
        get
    }
    var privateKeyToData: Data {
        get
    }
    var privateKeyToString: String {
        get
    }
    func equal(_ value: PrivateKey) -> Bool
}

extension Data: PrivateKey {
    public static var privateKeyMethod: String {
        //An elliptic curve that enables X25519 key agreement and ed25519 signatures.
        //A Curve25519 private key used to create cryptographic signatures.
        "Curve25519"
    }
    public static var privateKeyBits: Int = 256
    public static var privateKeyBytes: Int = 32
    public var privateKeyToData: Data {
        self
    }
    public var privateKeyToString: String {
        self.base64String
    }
    public func equal(_ value: PrivateKey) -> Bool {
        self.privateKeyToData == value.privateKeyToData
    }
}
