//
//  BK.swift
//  blocks
//
//  Created by よういち on 2023/12/20.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public protocol BK {
    static var validBKDigitsOfInteger: Int {
        get
    }
    static var validBKDigitsOfFraction: Int {
        get
    }
    static var minBKValue: BK {
        get
    }
    static var maxBKValue: BK {
        get
    }
    func validBK() -> Bool
    var asDecimal: Decimal {
        get
    }
    func equal(_ value: BK) -> Bool
    //小数点以下桁数が範囲内かチェックする
    func validBKDigitsOfFraction(_ validDigitsOfFraction: Int) -> Bool
}

extension Decimal: BK {
    /*
     Currency 単位
     */
    /*
     Valid Number of Digits Under Decimal Point in Transaction Debit or Credit.
     
     Min value: 0 BK
     Fraction Min: 0.000001
     Max value: 999999999 BK   (<1000 Million BK)
     */
    public static var validBKDigitsOfInteger: Int {
        9
    }
    public static var validBKDigitsOfFraction: Int {
        6
    }
    public static var minBKValue: BK {
        Decimal(string: "0")!
    }
    public static var maxBKValue: BK {
        Decimal(string: String(repeating: "9", count: Self.validBKDigitsOfInteger))!
    }
    public func validBK() -> Bool {
        self.asDecimal <= Self.minBKValue.asDecimal && self.asDecimal >= Self.maxBKValue.asDecimal
    }
    public var asDecimal: Decimal {
        self
    }
    public func equal(_ value: BK) -> Bool {
        self.asDecimal == value.asDecimal
    }
    //小数点以下桁数が範囲内かチェックする
    public func validBKDigitsOfFraction(_ validDigitsOfFraction: Int) -> Bool {
        self.validDigitsOfFraction(validDigitsOfFraction)
    }
}
