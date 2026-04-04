#if os(macOS)
import Foundation

enum MacTextInputDeleteResult: Equatable {
    case stateOnly
    case hostBackspaces(Int)
}

struct MacTextInputCommitResult: Equatable {
    let backspaceCount: Int
    let text: String
}

final class MacTextInputState {
    private(set) var storage = NSMutableString()
    private(set) var selectedRange = NSRange(location: 0, length: 0)
    private(set) var markedRange: NSRange?

    var hasMarkedText: Bool {
        markedRange != nil
    }

    var markedText: String? {
        guard let markedRange else {
            return nil
        }
        return storage.substring(with: markedRange)
    }

    var string: String {
        storage as String
    }

    func reset() {
        storage.setString("")
        selectedRange = NSRange(location: 0, length: 0)
        markedRange = nil
    }

    func insertText(_ text: String, replacementRange: NSRange) -> MacTextInputCommitResult {
        let rangeToReplace = resolvedRange(for: replacementRange)
        let backspaceCount = committedCharacterCount(in: rangeToReplace)
        replaceCharacters(in: rangeToReplace, with: text)
        let endLocation = rangeToReplace.location + utf16Length(of: text)
        selectedRange = NSRange(location: endLocation, length: 0)
        markedRange = nil
        return MacTextInputCommitResult(backspaceCount: backspaceCount, text: text)
    }

    func setMarkedText(_ text: String?, selectedRange newSelectedRange: NSRange, replacementRange: NSRange) {
        let rangeToReplace = resolvedRange(for: replacementRange)

        guard let text else {
            replaceCharacters(in: rangeToReplace, with: "")
            markedRange = nil
            selectedRange = NSRange(location: rangeToReplace.location, length: 0)
            return
        }

        replaceCharacters(in: rangeToReplace, with: text)

        let markedLength = utf16Length(of: text)
        let mark = NSRange(location: rangeToReplace.location, length: markedLength)
        markedRange = mark

        let relativeSelection = clampedRange(newSelectedRange, upperBound: markedLength)
        selectedRange = NSRange(location: mark.location + relativeSelection.location,
                                length: relativeSelection.length)
    }

    func unmarkText() {
        guard let markedRange else {
            return
        }

        selectedRange = NSRange(location: markedRange.location + markedRange.length, length: 0)
        self.markedRange = nil
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        guard let clamped = clampedRange(range) else {
            actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
            return nil
        }
        actualRange?.pointee = clamped
        return NSAttributedString(string: storage.substring(with: clamped))
    }

    func deleteBackward() -> MacTextInputDeleteResult? {
        guard let rangeToDelete = deletionRange() else {
            return nil
        }

        let deletedCharacterCount = composedCharacterCount(in: rangeToDelete)
        let deletedInsideMarkedText = markedRange.map {
            rangeToDelete.location >= $0.location && NSMaxRange(rangeToDelete) <= NSMaxRange($0)
        } ?? false

        storage.replaceCharacters(in: rangeToDelete, with: "")
        selectedRange = NSRange(location: rangeToDelete.location, length: 0)
        adjustMarkedRangeAfterDeleting(rangeToDelete)

        return deletedInsideMarkedText ? .stateOnly : .hostBackspaces(deletedCharacterCount)
    }

    private func deletionRange() -> NSRange? {
        let clampedSelection = clampedRange(selectedRange) ?? NSRange(location: 0, length: 0)

        if clampedSelection.length > 0 {
            return composedCharacterRange(for: clampedSelection)
        }

        guard storage.length > 0, clampedSelection.location > 0 else {
            return nil
        }

        let deleteIndex = min(storage.length - 1, clampedSelection.location - 1)
        return (storage as NSString).rangeOfComposedCharacterSequence(at: deleteIndex)
    }

    private func adjustMarkedRangeAfterDeleting(_ deletedRange: NSRange) {
        guard let markedRange else {
            return
        }

        let deletedEnd = NSMaxRange(deletedRange)
        let markedEnd = NSMaxRange(markedRange)

        if deletedEnd <= markedRange.location {
            self.markedRange = NSRange(location: markedRange.location - deletedRange.length,
                                       length: markedRange.length)
            return
        }

        if deletedRange.location >= markedEnd {
            return
        }

        let overlap = NSIntersectionRange(markedRange, deletedRange)
        let newLength = markedRange.length - overlap.length
        if newLength <= 0 {
            self.markedRange = nil
            return
        }

        let newLocation = min(markedRange.location, deletedRange.location)
        self.markedRange = NSRange(location: newLocation, length: newLength)
    }

    private func committedCharacterCount(in range: NSRange) -> Int {
        guard range.length > 0 else {
            return 0
        }

        guard let markedRange else {
            return composedCharacterCount(in: range)
        }

        let overlap = NSIntersectionRange(range, markedRange)
        if overlap.length == 0 {
            return composedCharacterCount(in: range)
        }

        var count = 0
        if range.location < overlap.location {
            let prefix = NSRange(location: range.location, length: overlap.location - range.location)
            count += composedCharacterCount(in: prefix)
        }
        if NSMaxRange(overlap) < NSMaxRange(range) {
            let suffix = NSRange(location: NSMaxRange(overlap), length: NSMaxRange(range) - NSMaxRange(overlap))
            count += composedCharacterCount(in: suffix)
        }
        return count
    }

    private func composedCharacterCount(in range: NSRange) -> Int {
        guard let clamped = clampedRange(range), clamped.length > 0 else {
            return 0
        }

        let string = storage as NSString
        let end = NSMaxRange(clamped)
        var count = 0
        var index = clamped.location

        while index < end {
            let sequence = string.rangeOfComposedCharacterSequence(at: index)
            count += 1
            index = NSMaxRange(sequence)
        }

        return count
    }

    private func resolvedRange(for proposedRange: NSRange) -> NSRange {
        if let clamped = clampedRange(proposedRange) {
            return clamped
        }
        if let markedRange {
            return markedRange
        }
        return clampedRange(selectedRange) ?? NSRange(location: 0, length: 0)
    }

    private func replaceCharacters(in range: NSRange, with text: String) {
        storage.replaceCharacters(in: range, with: text)
    }

    private func composedCharacterRange(for range: NSRange) -> NSRange {
        guard range.length > 0 else {
            return range
        }
        return (storage as NSString).rangeOfComposedCharacterSequences(for: range)
    }

    private func utf16Length(of text: String) -> Int {
        (text as NSString).length
    }

    private func clampedRange(_ range: NSRange?) -> NSRange? {
        guard let range else {
            return nil
        }
        guard range.location != NSNotFound else {
            return nil
        }
        return clampedRange(range, upperBound: storage.length)
    }

    private func clampedRange(_ range: NSRange, upperBound: Int) -> NSRange {
        let location = max(0, min(range.location, upperBound))
        let length = max(0, min(range.length, upperBound - location))
        return NSRange(location: location, length: length)
    }
}
#endif
