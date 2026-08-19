import Foundation
import Core

/// Packs and unpacks a drive's samples.
///
/// A ninety-minute drive is about 54,000 samples. One row each would be a
/// database SwiftData would handle badly and a table nobody would ever query,
/// so the whole array is one blob: binary property list (compact, and it
/// keeps `Codable` doing the work), then LZFSE (fast, and built in).
///
/// The blob is the record. Analysis can always be run again; these numbers
/// cannot be recorded again.
public enum SampleCodec {
    public enum Failure: Error {
        case compression(String)
    }

    public static func encode(_ samples: [Sample]) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let plist = try encoder.encode(samples)
        do {
            return try (plist as NSData).compressed(using: .lzfse) as Data
        } catch {
            throw Failure.compression(error.localizedDescription)
        }
    }

    public static func decode(_ data: Data) throws -> [Sample] {
        let plist: Data
        do {
            plist = try (data as NSData).decompressed(using: .lzfse) as Data
        } catch {
            throw Failure.compression(error.localizedDescription)
        }
        return try PropertyListDecoder().decode([Sample].self, from: plist)
    }
}

/// The analysis cache. Kept separate from the samples so a schema bump throws
/// away the opinion and never the evidence.
public enum BlobCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try (encoder.encode(value) as NSData).compressed(using: .lzfse) as Data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let plist = try (data as NSData).decompressed(using: .lzfse) as Data
        return try PropertyListDecoder().decode(type, from: plist)
    }
}
