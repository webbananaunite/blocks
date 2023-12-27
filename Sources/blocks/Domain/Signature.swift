//
//  Signature.swift
//  blocks
//
//  Created by よういち on 2023/12/19.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public protocol Signature {
    static var signatureBits: Int {
        get
    }
    static var signatureBytes: Int {
        get
    }
    func validSignature() -> Bool
    var toString: String {
        get
    }
    var signatureToData: Data {
        get
    }
    func equal(_ value: Signature) -> Bool
}

extension Data: Signature {
    /*
     signature
     
     MCRXxH2QUz     80+6=480+36=516-4=512bits
     VkWhT4eTCd
     EmJSWmT602
     /47oIZY9zC
     DFXsg6XUX4
     dKu5KqaToE
     bWjGhUA/2a
     jG3V1pM7LR
     SHgNCA==
     ",
     PgryseHTD+gDuECierXXpNDfqYoGYIBgY2zkC1UeZXqcmZRuAdVHnPpr1+jR5MoSKKRwmpVMbWt8KOonSjAdAw==
     "signature":"
     AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==
     "
     
     cf.
     publicKey
        ForSignature
     W3uLoPfcm5olRT5ACb+SDrhvShjHsV8cafjPjXw3ZMU=   43文字＋＝　240+18=258-2=256bit
     
     privateKey
        ForEncryption
     UOyJV8zrEfnaAKc3zoUfSbcTb6VIHDIads3sE3s+TFA=
     */
    public static var signatureBits: Int = 512
    public static var signatureBytes: Int = 64
    public func validSignature() -> Bool {
        self.count == Self.signatureBytes
    }
    public var toString: String {
        self.base64String
    }
    public var signatureToData: Data {
        self
    }
    public func equal(_ value: Signature) -> Bool {
        self == value.signatureToData
    }
}
