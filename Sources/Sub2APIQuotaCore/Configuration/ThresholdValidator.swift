import Foundation

public enum ThresholdValidationError: Error, Equatable {
    case invalidNumber
    case tooManyFractionDigits
}

public enum ThresholdValidator {
    public static func parse(_ rawValue: String) throws -> Decimal {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else {
            throw ThresholdValidationError.invalidNumber
        }

        let components = trimmedValue.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count <= 2 else {
            throw ThresholdValidationError.invalidNumber
        }

        if components.count == 2, components[1].count > 2 {
            throw ThresholdValidationError.tooManyFractionDigits
        }

        guard isValidNumericText(components) else {
            throw ThresholdValidationError.invalidNumber
        }

        guard let decimalValue = Decimal(string: trimmedValue, locale: Locale(identifier: "en_US_POSIX")),
              decimalValue >= 0 else {
            throw ThresholdValidationError.invalidNumber
        }

        return decimalValue
    }

    private static func isValidNumericText(_ components: [Substring]) -> Bool {
        guard let integerPart = components.first else {
            return false
        }

        if components.count == 1 {
            return isSignedDigits(integerPart)
        }

        guard components.count == 2 else {
            return false
        }

        let fractionPart = components[1]
        guard fractionPart.isEmpty == false else {
            return false
        }

        return isSignedDigits(integerPart) && fractionPart.allSatisfy(\.isNumber)
    }

    private static func isSignedDigits(_ value: Substring) -> Bool {
        guard let firstCharacter = value.first else {
            return false
        }

        if firstCharacter == "+" || firstCharacter == "-" {
            let digits = value.dropFirst()
            return digits.isEmpty == false && digits.allSatisfy(\.isNumber)
        }

        return value.allSatisfy(\.isNumber)
    }
}
