//
//  Copyright © 2021 Yahoo
//


import Foundation

public struct BGEvent: Equatable {
    public let sequence: UInt
    public let timestamp: Date
    public let impulse: String?
    
    public static let unknownPast = BGEvent(sequence: 0, timestamp: Date(timeIntervalSince1970: 0), impulse: nil)
}
