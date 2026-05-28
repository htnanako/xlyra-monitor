import Foundation
import Testing
@testable import Sub2APIQuotaCore

@Suite("ThresholdValidatorTests")
struct ThresholdValidatorTests {
    @Test
    func acceptsZeroIntegerAndTwoDigitDecimalThresholds() throws {
        #expect(try ThresholdValidator.parse("0") == Decimal(string: "0"))
        #expect(try ThresholdValidator.parse("10") == Decimal(string: "10"))
        #expect(try ThresholdValidator.parse("10.25") == Decimal(string: "10.25"))
    }

    @Test
    func trimsWhitespaceAroundValidThresholds() throws {
        #expect(try ThresholdValidator.parse(" \n10.25\t ") == Decimal(string: "10.25"))
    }

    @Test
    func rejectsEmptyAndWhitespaceOnlyInput() {
        #expect(throws: ThresholdValidationError.invalidNumber) {
            try ThresholdValidator.parse("")
        }

        #expect(throws: ThresholdValidationError.invalidNumber) {
            try ThresholdValidator.parse(" \n\t ")
        }
    }

    @Test
    func rejectsNegativeThresholds() {
        #expect(throws: ThresholdValidationError.invalidNumber) {
            try ThresholdValidator.parse("-1")
        }
    }

    @Test
    func rejectsNonNumericThresholds() {
        #expect(throws: ThresholdValidationError.invalidNumber) {
            try ThresholdValidator.parse("abc")
        }
    }

    @Test
    func rejectsMoreThanTwoFractionDigits() {
        #expect(throws: ThresholdValidationError.tooManyFractionDigits) {
            try ThresholdValidator.parse("1.234")
        }
    }
}
