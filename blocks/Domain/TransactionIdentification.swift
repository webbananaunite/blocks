//
//  TransactionIdentification.swift
//  blocks
//
//  Created by よういち on 2023/12/20.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public protocol TransactionIdentification {
    static var transactionIdPrefixChars: Int {
        get
    }
    static var transactionIdentificationChars: Int {
        get
    }
    var transactionIdentificationToString: String {
        get
    }
    func equal(_ value: TransactionIdentification) -> Bool
}

extension String: TransactionIdentification {
    public static var transactionIdPrefixChars: Int {
        2
    }
    public static var transactionIdentificationChars: Int {
        Self.transactionIdPrefixChars + String.hashStringChars
    }
    public var transactionIdentificationToString: String {
        self
    }
    public func equal(_ value: TransactionIdentification) -> Bool {
        self.transactionIdentificationToString == value.transactionIdentificationToString
    }
}
