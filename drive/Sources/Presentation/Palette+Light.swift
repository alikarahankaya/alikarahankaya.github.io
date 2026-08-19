import Analysis

public extension Palette {
    /// One palette per light. The drive's own sun decides how it is drawn,
    /// which is why a library ends up sorted by the light it was driven in.
    init(_ light: Light) {
        switch light {
        case .night: self = .night
        case .dawn: self = .dawn
        case .morning: self = .morning
        case .day: self = .day
        case .golden: self = .golden
        case .dusk: self = .dusk
        }
    }
}
