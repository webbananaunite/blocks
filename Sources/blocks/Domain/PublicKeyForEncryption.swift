//
//  PublicKeyForEncryption.swift
//  blocks
//
//  Created by よういち on 2023/12/20.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public protocol PublicKeyForEncryption {
    static var publicKeyForEncryptionMethod: String {
        get
    }
    static var publicKeyForEncryptionBits: Int {
        get
    }
    static var publicKeyForEncryptionBytes: Int {
        get
    }
    var publicKeyForEncryptionToData: Data {
        get
    }
    var publicKeyForEncryptionToString: String {
        get
    }
    func equal(_ value: PublicKey) -> Bool
}

extension Data: PublicKeyForEncryption {
    public static var publicKeyForEncryptionMethod: String {
        //A mechanism used to create a shared secret between two users by
        //performing X25519 key agreement.
        //Creates a Curve25519 public key for key agreement from a
        //collection of bytes.
        "Curve25519"
    }
    public static var publicKeyForEncryptionBits: Int = 256
    public static var publicKeyForEncryptionBytes: Int = 32
    public var publicKeyForEncryptionToData: Data {
        self
    }
    public var publicKeyForEncryptionToString: String {
        self.base64String
    }
    public func equal(_ value: PublicKeyForEncryption) -> Bool {
        self.publicKeyForEncryptionToData == value.publicKeyForEncryptionToData
    }
}
