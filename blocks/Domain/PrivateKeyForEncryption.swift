//
//  PrivateKeyForEncryption.swift
//  blocks
//
//  Created by よういち on 2023/12/20.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public protocol PrivateKeyForEncryption {
    static var privateKeyForEncryptionMethod: String {
        get
    }
    static var privateKeyForEncryptionBits: Int {
        get
    }
    static var privateKeyForEncryptionBytes: Int {
        get
    }
    var privateKeyForEncryptionToData: Data {
        get
    }
    var privateKeyForEncryptionToString: String {
        get
    }
    func equal(_ value: PublicKey) -> Bool
}

extension Data: PrivateKeyForEncryption {
    public static var privateKeyForEncryptionMethod: String {
        //A mechanism used to create a shared secret between two users by
        //performing X25519 key agreement.
        //Creates a Curve25519 public key for key agreement from a
        //collection of bytes.
        "Curve25519"
    }
    public static var privateKeyForEncryptionBits: Int = 256
    public static var privateKeyForEncryptionBytes: Int = 32
    public var privateKeyForEncryptionToData: Data {
        self
    }
    public var privateKeyForEncryptionToString: String {
        self.base64String
    }
    public func equal(_ value: PrivateKeyForEncryption) -> Bool {
        self.privateKeyForEncryptionToData == value.privateKeyForEncryptionToData
    }
}
