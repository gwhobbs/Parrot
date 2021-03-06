import Foundation

//
// ProtoEnum
//

public protocol _ProtoEnum: Codable {
    var rawValue: Int { get }
    init(_ rawValue: Int)
}

public protocol ProtoEnum: _ProtoEnum, ExpressibleByIntegerLiteral, RawRepresentable, Hashable {}
public extension ProtoEnum {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
    public init?(rawValue value: Int) {
        self.init(value)
    }
    public var hashValue: Int {
        return self.rawValue.hashValue
    }
}

// TODO: Unsure why, but in Swift 4.1+, RawRepresentable Codable synthesis yields CodingKeys?
// This should force-fix that just for ProtoEnum.
public extension ProtoEnum {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(Int.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

//
// ProtoMessage
//

public protocol _ProtoMessage: Codable {}
public typealias ProtoMessage = _ProtoMessage & Hashable

//
// ServiceRequest/Response
//

/// Defines a protobuf message used as an RPC request.
internal protocol ServiceRequest: ProtoMessage {
    
    /// Links the protobuf message used as the response to this request.
    associatedtype Response: ServiceResponse
    
    /// Specifies the remote location this RPC request should be sent to.
    static var location: String { get }
    
    /// The client-sent header describing the RPC request.
    var request_header: RequestHeader? { get set }
}

/// Defines a protobuf message used as an RPC response.
internal protocol ServiceResponse: ProtoMessage {
    
    /// The server-sent header describing the RPC response.
    var response_header: ResponseHeader? { get set }
}


/// An error that may occur during Service RPC transmission.
public enum ServiceError: Error {
    
    /// The server returned an error (status code and description).
    case server(ResponseStatus, String)
    
    /// An unknown error occurred during RPC transmission.
    case unknown
}

//
// Hashable Utils
//

// Generate 64-bit random value in a range that is divisible by upper_bound:
// from @martin-r: http://stackoverflow.com/questions/26549830/swift-random-number-for-64-bit-integers
func random64(_ upper_bound: UInt64) -> UInt64 {
    let range = UInt64.max - UInt64.max % upper_bound
    var rnd: UInt64 = 0
    repeat {
        arc4random_buf(&rnd, MemoryLayout.size(ofValue: rnd))
    } while rnd >= range
    return rnd % upper_bound
}

extension Optional: Hashable where Wrapped: Hashable {
    public var hashValue: Int {
        return self?.hashValue ?? 0
    }
}

extension Array: Hashable where Element: Hashable {
    public var hashValue: Int {
        return self.reduce(5381) { ($0 << 5) &+ $0 &+ $1.hashValue }
    }
}

extension Dictionary where Key: Hashable, Value: Hashable {
    public var hashValue: Int {
        return self.reduce(5381) { ($0 << 5) &+ $0 &+ $1.key.hashValue &+ $1.value.hashValue }
    }
}

//
//
//

// Convert a microsecond timestamp to an Date instance.
// Convert UTC datetime to microsecond timestamp used by Hangouts.
private let MicrosecondsPerSecond: Double = 1000000.0
extension Date {
    init(UTC: UInt64?) {
        self = Date(timeIntervalSince1970: (Double(UTC ?? 0) / MicrosecondsPerSecond))
    }
    func toUTC() -> UInt64 {
        return UInt64(self.timeIntervalSince1970 * MicrosecondsPerSecond)
    }
}
