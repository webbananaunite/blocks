//
//  PublicKey.swift
//  blocks
//
//  Created by よういち on 2023/12/20.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public protocol PublicKey {
    static var publicKeyMethod: String {
        get
    }
    static var publicKeyBits: Int {
        get
    }
    static var publicKeyBytes: Int {
        get
    }
    var publicKeyToData: Data {
        get
    }
    var publicKeyToString: String {
        get
    }
    func equal(_ value: PublicKey) -> Bool
}

extension Data: PublicKey {
    public static var publicKeyMethod: String {
        //An elliptic curve that enables X25519 key agreement and ed25519 signatures.
        //A Curve25519 public key used to verify cryptographic signatures.
        "Curve25519"
    }
    public static var publicKeyBits: Int = 256
    public static var publicKeyBytes: Int = 32
    public var publicKeyToData: Data {
        self
    }
    public var publicKeyToString: String {
        self.base64String
    }
    public func equal(_ value: PublicKey) -> Bool {
        self.publicKeyToData == value.publicKeyToData
    }
}
