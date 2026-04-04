#if os(macOS)
import Foundation
import Testing

@testable import SwiftTerm

@Suite(.serialized)
final class MacTextInputStateTests {
    @Test func testVariationSelectorSequenceDeletesByGrapheme() {
        let state = MacTextInputState()
        _ = state.insertText("☀️", replacementRange: NSRange(location: NSNotFound, length: 0))

        #expect(state.selectedRange == NSRange(location: 2, length: 0))

        let result = state.deleteBackward()

        #expect(result == .hostBackspaces(1))
        #expect(state.string == "")
        #expect(state.selectedRange == NSRange(location: 0, length: 0))
        #expect(state.markedRange == nil)
    }

    @Test func testBackspaceDeletesAsciiAfterEmoji() {
        let state = MacTextInputState()
        _ = state.insertText("a☀️", replacementRange: NSRange(location: NSNotFound, length: 0))

        let firstDelete = state.deleteBackward()
        #expect(firstDelete == .hostBackspaces(1))
        #expect(state.string == "a")
        #expect(state.selectedRange == NSRange(location: 1, length: 0))

        let secondDelete = state.deleteBackward()
        #expect(secondDelete == .hostBackspaces(1))
        #expect(state.string == "")
        #expect(state.selectedRange == NSRange(location: 0, length: 0))
        #expect(state.markedRange == nil)
    }

    @Test func testSetMarkedTextTracksUtf16Ranges() {
        let state = MacTextInputState()
        state.setMarkedText("☀️", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))

        #expect(state.string == "☀️")
        #expect(state.markedRange == NSRange(location: 0, length: 2))
        #expect(state.selectedRange == NSRange(location: 2, length: 0))

        var actual = NSRange(location: NSNotFound, length: 0)
        let attributed = state.attributedSubstring(forProposedRange: NSRange(location: 0, length: 2), actualRange: &actual)
        #expect(attributed?.string == "☀️")
        #expect(actual == NSRange(location: 0, length: 2))
    }

    @Test func testDeleteBackwardInsideMarkedTextDoesNotEmitHostBackspace() {
        let state = MacTextInputState()
        state.setMarkedText("☀️", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))

        let result = state.deleteBackward()

        #expect(result == .stateOnly)
        #expect(state.string == "")
        #expect(state.selectedRange == NSRange(location: 0, length: 0))
        #expect(state.markedRange == nil)
    }

    @Test func testInsertTextReplacesMarkedTextWithoutBackspacingCommittedText() {
        let state = MacTextInputState()
        state.setMarkedText("てす", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))

        let commit = state.insertText("☀️", replacementRange: NSRange(location: NSNotFound, length: 0))

        #expect(commit == MacTextInputCommitResult(backspaceCount: 0, text: "☀️"))
        #expect(state.string == "☀️")
        #expect(state.selectedRange == NSRange(location: 2, length: 0))
        #expect(state.markedRange == nil)
    }

    @Test func testReplacingCommittedEmojiUsesOneHostBackspace() {
        let state = MacTextInputState()
        _ = state.insertText("☀️", replacementRange: NSRange(location: NSNotFound, length: 0))

        let commit = state.insertText("b", replacementRange: NSRange(location: 0, length: 2))

        #expect(commit == MacTextInputCommitResult(backspaceCount: 1, text: "b"))
        #expect(state.string == "b")
        #expect(state.selectedRange == NSRange(location: 1, length: 0))
        #expect(state.markedRange == nil)
    }
}
#endif
