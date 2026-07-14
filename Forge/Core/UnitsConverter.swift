import Foundation

/// Conversions between canonical storage units (kg, meters, cm) and display units.
enum UnitsConverter {
    static let kgPerPound = 0.45359237
    static let metersPerMile = 1609.344
    static let cmPerInch = 2.54

    // MARK: Weight

    static func displayWeight(kg: Double, unit: WeightUnit) -> Double {
        unit == .kilograms ? kg : kg / kgPerPound
    }

    static func weightKg(fromDisplay value: Double, unit: WeightUnit) -> Double {
        unit == .kilograms ? value : value * kgPerPound
    }

    // MARK: Distance

    static func displayDistance(meters: Double, unit: DistanceUnit) -> Double {
        unit == .kilometers ? meters / 1000.0 : meters / metersPerMile
    }

    static func distanceMeters(fromDisplay value: Double, unit: DistanceUnit) -> Double {
        unit == .kilometers ? value * 1000.0 : value * metersPerMile
    }

    // MARK: Length

    static func displayLength(cm: Double, unit: LengthUnit) -> Double {
        unit == .centimeters ? cm : cm / cmPerInch
    }

    static func lengthCm(fromDisplay value: Double, unit: LengthUnit) -> Double {
        unit == .centimeters ? value : value * cmPerInch
    }
}
