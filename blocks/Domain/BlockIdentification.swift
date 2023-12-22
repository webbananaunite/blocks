//
//  BlockIdentification.swift
//  blocks
//
//  Created by よういち on 2023/12/20.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public protocol BlockIdentification {
    var identificationChars: Int {
        get
    }
    var identificationToString: String {
        get
    }
    func equal(_ value: BlockIdentification) -> Bool
}

extension String: BlockIdentification {
    public var identificationChars: Int {
        String.hashStringChars
    }
    public var identificationToString: String {
        self
    }
    public func equal(_ value: BlockIdentification) -> Bool {
        self.identificationToString == value.identificationToString
    }
}
