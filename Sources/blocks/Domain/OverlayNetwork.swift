//
//  OverlayNetwork.swift
//  blocks
//
//  Created by よういち on 2023/08/18.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import overlayNetwork

public class Dht: overlayNetwork.Dht {
}

public struct IpaddressV4: IpaddressV4Protocol {
    public init?() {
        regions = ["0","0","0","0"]
    }
    
    //v4
    public var regions: [String] {
        didSet {
            if regions.count > Self.IpAddressRegionCount {regions = oldValue}
        }
    }
}
