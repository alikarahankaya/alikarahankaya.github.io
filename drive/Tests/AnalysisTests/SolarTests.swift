import Testing
import Foundation
@testable import Analysis

@Suite("Sun")
struct SolarTests {
    @Test("Altitude matches published figures")
    func knownAltitudes() {
        // London, midsummer noon UTC: the sun is 62° up.
        let londonNoon = Date(timeIntervalSince1970: 1_718_971_200)  // 2024-06-21 12:00Z
        #expect(abs(Solar.altitude(at: londonNoon, lat: 51.5074, lon: -0.1278) - 61.9) < 0.4)

        // The same night, twelve hours earlier: well below the horizon.
        let londonMidnight = Date(timeIntervalSince1970: 1_718_928_000)
        #expect(abs(Solar.altitude(at: londonMidnight, lat: 51.5074, lon: -0.1278) + 15.1) < 0.4)

        // Sydney, midwinter local noon: low, and in the north.
        let sydneyNoon = Date(timeIntervalSince1970: 1_718_935_200)  // 2024-06-21 02:00Z
        #expect(abs(Solar.altitude(at: sydneyNoon, lat: -33.87, lon: 151.21) - 32.7) < 0.5)
    }

    @Test("The sun is known to be rising in the morning and setting in the evening")
    func risingAndSetting() {
        let morning = Date(timeIntervalSince1970: 1_718_167_500)     // 2024-06-12 04:45Z
        let evening = Date(timeIntervalSince1970: 1_718_219_700)     // 2024-06-12 19:15Z
        #expect(Solar.isRising(at: morning, lat: 46.5, lon: 11))
        #expect(!Solar.isRising(at: evening, lat: 46.5, lon: 11))
    }

    @Test("Each band comes out of the altitude it is defined by")
    func bands() {
        let alpine = (lat: 46.5, lon: 11.0)
        // -1.6°, setting.
        #expect(Solar.light(at: Date(timeIntervalSince1970: 1_718_219_700),
                            lat: alpine.lat, lon: alpine.lon) == .dusk)
        // -3.9°, rising.
        #expect(Solar.light(at: Date(timeIntervalSince1970: 1_718_161_200),
                            lat: alpine.lat, lon: alpine.lon) == .dawn)
        // +11.6°, rising.
        #expect(Solar.light(at: Date(timeIntervalSince1970: 1_718_167_500),
                            lat: alpine.lat, lon: alpine.lon) == .morning)
        // +58°, high.
        #expect(Solar.light(at: Date(timeIntervalSince1970: 1_718_197_200),
                            lat: alpine.lat, lon: alpine.lon) == .day)
        // +3.1°, setting: the long light.
        #expect(Solar.light(at: Date(timeIntervalSince1970: 1_718_217_600),
                            lat: alpine.lat, lon: alpine.lon) == .golden)
        // Deep midwinter night.
        #expect(Solar.light(at: Date(timeIntervalSince1970: 1_733_265_000),
                            lat: alpine.lat, lon: alpine.lon) == .night)
    }
}
