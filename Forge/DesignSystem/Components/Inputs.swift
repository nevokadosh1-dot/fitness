import SwiftUI

/// Labeled text field on an elevated surface.
struct FormField: View {
    var label: String
    var placeholder: String = ""
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label.uppercased())
                .font(.forgeOverline)
                .tracking(0.8)
                .foregroundStyle(Theme.textTertiary)
            TextField(placeholder, text: $text, axis: axis)
                .font(.forgeBody)
                .foregroundStyle(Theme.textPrimary)
                .padding(Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .fill(Theme.surfaceElevated)
                )
        }
    }
}

/// Numeric entry with +/- stepper buttons; the increment is configurable.
struct NumberStepperField: View {
    var label: String
    @Binding var value: Double
    var increment: Double
    var range: ClosedRange<Double> = 0...10_000
    var unit: String = ""
    var decimals: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if !label.isEmpty {
                Text(label.uppercased())
                    .font(.forgeOverline)
                    .tracking(0.8)
                    .foregroundStyle(Theme.textTertiary)
            }
            HStack(spacing: Spacing.s) {
                IconButton(systemImage: "minus", size: 34) {
                    value = max(range.lowerBound, value - increment)
                    Haptics.light()
                }
                .accessibilityLabel("Decrease \(label)")

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    TextField("0", value: $value, format: .number.precision(.fractionLength(0...decimals)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.forgeStat)
                        .foregroundStyle(Theme.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.forgeCaption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, Spacing.s)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                        .fill(Theme.surfaceElevated)
                )

                IconButton(systemImage: "plus", size: 34) {
                    value = min(range.upperBound, value + increment)
                    Haptics.light()
                }
                .accessibilityLabel("Increase \(label)")
            }
        }
    }
}

/// Integer variant of the stepper field.
struct IntStepperField: View {
    var label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...1000
    var step: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if !label.isEmpty {
                Text(label.uppercased())
                    .font(.forgeOverline)
                    .tracking(0.8)
                    .foregroundStyle(Theme.textTertiary)
            }
            HStack(spacing: Spacing.s) {
                IconButton(systemImage: "minus", size: 34) {
                    value = max(range.lowerBound, value - step)
                    Haptics.light()
                }
                .accessibilityLabel("Decrease \(label)")

                TextField("0", value: $value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.forgeStat)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                            .fill(Theme.surfaceElevated)
                    )

                IconButton(systemImage: "plus", size: 34) {
                    value = min(range.upperBound, value + step)
                    Haptics.light()
                }
                .accessibilityLabel("Increase \(label)")
            }
        }
    }
}

/// RPE picker: 6–10 in half steps, the range that matters in practice.
struct RPESelector: View {
    @Binding var rpe: Double?

    private let options: [Double] = [6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(options, id: \.self) { option in
                    Button {
                        rpe = (rpe == option) ? nil : option
                        Haptics.light()
                    } label: {
                        Text(Formatting.trimmed(option, maxDecimals: 1))
                            .font(.forgeCaption)
                            .foregroundStyle(rpe == option ? Color.black : Theme.textSecondary)
                            .frame(width: 40, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                                    .fill(rpe == option ? Theme.accent : Theme.surfaceElevated)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("RPE \(Formatting.trimmed(option, maxDecimals: 1))")
                }
            }
        }
    }
}

/// 1–10 rating row used for intensity / energy / soreness scores.
struct ScaleSelector: View {
    var label: String
    @Binding var value: Int?
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label.uppercased())
                .font(.forgeOverline)
                .tracking(0.8)
                .foregroundStyle(Theme.textTertiary)
            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { number in
                    Button {
                        value = (value == number) ? nil : number
                        Haptics.light()
                    } label: {
                        Text("\(number)")
                            .font(.forgeCaption)
                            .foregroundStyle(value == number ? Color.black : Theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(value == number ? tint : Theme.surfaceElevated)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Duration entry as minutes + seconds.
struct DurationField: View {
    var label: String
    @Binding var totalSeconds: Double

    private var hours: Binding<Int> {
        Binding(
            get: { Int(totalSeconds) / 3600 },
            set: { totalSeconds = Double($0 * 3600 + (Int(totalSeconds) % 3600)) }
        )
    }
    private var minutes: Binding<Int> {
        Binding(
            get: { (Int(totalSeconds) % 3600) / 60 },
            set: { totalSeconds = Double((Int(totalSeconds) / 3600) * 3600 + $0 * 60 + Int(totalSeconds) % 60) }
        )
    }
    private var seconds: Binding<Int> {
        Binding(
            get: { Int(totalSeconds) % 60 },
            set: { totalSeconds = Double((Int(totalSeconds) / 60) * 60 + $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label.uppercased())
                .font(.forgeOverline)
                .tracking(0.8)
                .foregroundStyle(Theme.textTertiary)
            HStack(spacing: Spacing.s) {
                unitField(binding: hours, unit: "h")
                unitField(binding: minutes, unit: "m")
                unitField(binding: seconds, unit: "s")
            }
        }
    }

    private func unitField(binding: Binding<Int>, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            TextField("0", value: binding, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.forgeStat)
                .foregroundStyle(Theme.textPrimary)
                .accessibilityIdentifier("\(label).\(unit)")
            Text(unit)
                .font(.forgeCaption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Radius.s, style: .continuous)
                .fill(Theme.surfaceElevated)
        )
    }
}
