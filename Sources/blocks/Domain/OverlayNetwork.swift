//
//  OverlayNetwork.swift
//  blocks
//
//  Created by よういち on 2023/08/18.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import overlayNetwork

public class StreamingBlocks: overlayNetwork.Streaming {
}

public class Dht: overlayNetwork.Dht {
}

public class AcceptStreamingBlocks: overlayNetwork.AcceptStreaming {
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

/*
 Only Use Network Framework Communication
 */
public protocol PeerConnectionDelegateNetwork: overlayNetwork.PeerConnectionDelegate {
}
@available(iOS 16.0, *)
public class PeerConnectionNetwork: overlayNetwork.PeerConnection {
}
@available(iOS 16.0, *)
public class PeerListenerNetwork: overlayNetwork.PeerListener {
}
