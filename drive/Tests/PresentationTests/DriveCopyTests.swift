import Testing
import Foundation
import Analysis
@testable import Presentation

/// The rule under test: a line exists only if it carries something.
@Suite("What a drive says")
struct DriveCopyTests {
    private var full: DrivePresentation { PreviewDrive.sample(light: .dusk) }

    private var motorway: DrivePresentation {
        var drive = PreviewDrive.sample(light: .day)
        drive.analysis.corners = []
        drive.analysis.flowDistance = 0
        drive.analysis.sinuosity = 1.004
        drive.weatherSummary = nil
        drive.placeName = nil
        drive.soundtrack = nil
        drive.note = nil
        return drive
    }

    @Test("Flow leads when there was flow")
    func flowLeads() {
        let copy = DriveCopy(full)
        #expect(copy.headline.label == "Longest unbroken sequence")
        // Distances follow the reader's locale, so the assertion is about
        // what the number is not: empty, or zero.
        #expect(!copy.headline.value.isEmpty)
        #expect(!copy.headline.value.hasPrefix("0"))
    }

    @Test("A road with no rhythm does not lead with a proud zero")
    func noFlowFallsBackToDistance() {
        let copy = DriveCopy(motorway)
        #expect(copy.headline.label == "Distance driven")
        #expect(!copy.headline.value.hasPrefix("0"))
    }

    @Test("Nothing is said about corners that are not there")
    func secondaryIsEarned() {
        #expect(DriveCopy(motorway).secondary.isEmpty)

        let copy = DriveCopy(full)
        #expect(copy.secondary.count == 2)
        #expect(copy.secondary[0].contains("corners"))
    }

    @Test("A straight road keeps its sinuosity to itself")
    func sinuosityNeedsAReason() {
        var drive = full
        drive.analysis.sinuosity = 1.01
        let items = DriveCopy(drive).secondary
        #expect(items.allSatisfy { !$0.contains("sin.") })
    }

    @Test("Unknown weather is not mentioned, and distance is never said twice")
    func tertiaryIsEarned() {
        let quiet = DriveCopy(motorway).tertiary
        // Light is always known — it comes from arithmetic, not a network —
        // so the conditions line survives; the rest does not.
        #expect(quiet.count == 2)
        #expect(quiet[0] == "Day")

        var withANote = motorway
        withANote.note = "Longer way home."
        #expect(DriveCopy(withANote).tertiary.count == 3)

        // Conditions and logistics; the preview drive has no note and no
        // soundtrack, so neither line is invented for it.
        let loud = DriveCopy(full).tertiary
        #expect(loud.count == 2)
        #expect(loud[0].contains("Dusk"))
        #expect(loud[0].contains("Passo Gardena"))
    }

    @Test("The poster says where and when")
    func posterFooter() {
        let footer = DriveCopy(full).posterFooter
        #expect(footer.contains("Passo Gardena"))
        #expect(footer.contains("Dusk"))
    }
}

@Suite("Copy")
struct FormattingTests {
    @Test("The year appears only when it is not this one")
    func dateDropsTheCurrentYear() {
        let zone = TimeZone(identifier: "Europe/Rome") ?? .gmt
        let june2024 = Date(timeIntervalSince1970: 1_718_219_700)
        let thisYear = Formatting.shortDate(
            june2024,
            timeZone: zone,
            relativeTo: june2024,
            locale: Locale(identifier: "en_GB")
        )
        let laterYear = Formatting.shortDate(
            june2024,
            timeZone: zone,
            relativeTo: june2024.addingTimeInterval(400 * 86_400),
            locale: Locale(identifier: "en_GB")
        )
        #expect(!thisYear.contains("2024"))
        #expect(laterYear.contains("2024"))
    }

    @Test("One corner is not one corners")
    func plural() {
        #expect(Formatting.corners(1) == "1 corner")
        #expect(Formatting.corners(118) == "118 corners")
    }

    @Test("The live number reads as a number, not a readout")
    func gFormatting() {
        #expect(LiveDriveView.format(0.4237) == "0.42 g")
        #expect(LiveDriveView.format(1) == "1.00 g")
    }
}
