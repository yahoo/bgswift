//
//  Copyright © 2021 Yahoo
//


import Foundation

public struct BGEvent: Equatable {
    public let sequence: UInt
    public let timestamp: Date
    public let impulse: String?
    
    public static let unknownPast: BGEvent = .init(sequence: 0, timestamp: Date(timeIntervalSince1970: 0), impulse: nil)
    
    init(sequence: UInt, timestamp: Date, impulse: String?) {
        self.sequence = sequence
        self.timestamp = timestamp
        self.impulse = impulse
    }
    
    public func happenedSince(sequence: UInt) -> Bool {
        self.sequence > 0 && self.sequence >= sequence
    }
}
