#if os(macOS)
import AppKit
import Foundation
import Testing

@testable import SwiftTerm

@Suite(.serialized)
final class MacTerminalViewTextInputTests {
    @Test func testShouldTrackInlinePaste() {
        #expect(TerminalView.shouldTrackInlinePaste("☀️"))
        #expect(TerminalView.shouldTrackInlinePaste("abc"))
        #expect(!TerminalView.shouldTrackInlinePaste("a\nb"))
        #expect(!TerminalView.shouldTrackInlinePaste("a\tb"))
        #expect(!TerminalView.shouldTrackInlinePaste("\u{7f}"))
    }

    @Test func testInlinePasteParticipatesInDeleteBudgeting() {
        let view = TerminalView(frame: .zero)
        view.insertText("a", replacementRange: NSRange(location: NSNotFound, length: 0), isPaste: false)
        view.insertText("☀️", replacementRange: NSRange(location: NSNotFound, length: 0), isPaste: true)

        #expect(view.textInputState.string == "a☀️")

        let deleteResult = view.textInputState.deleteBackward()
        #expect(deleteResult == .hostBackspaces(1))
        #expect(view.textInputState.string == "a")
    }

    @Test func testInlinePasteDeletesEmojiThenAscii() {
        let view = TerminalView(frame: .zero)
        view.insertText("a", replacementRange: NSRange(location: NSNotFound, length: 0), isPaste: false)
        view.insertText("☀️", replacementRange: NSRange(location: NSNotFound, length: 0), isPaste: true)

        let firstDelete = view.textInputState.deleteBackward()
        #expect(firstDelete == .hostBackspaces(1))
        #expect(view.textInputState.string == "a")

        let secondDelete = view.textInputState.deleteBackward()
        #expect(secondDelete == .hostBackspaces(1))
        #expect(view.textInputState.string.isEmpty)
        #expect(view.textInputState.selectedRange == NSRange(location: 0, length: 0))
    }

    @Test func testMultilinePasteDoesNotPopulateShadowState() {
        let view = TerminalView(frame: .zero)
        view.insertText("a", replacementRange: NSRange(location: NSNotFound, length: 0), isPaste: false)
        view.insertText("x\ny", replacementRange: NSRange(location: NSNotFound, length: 0), isPaste: true)

        #expect(view.textInputState.string.isEmpty)
        #expect(view.textInputState.selectedRange == NSRange(location: 0, length: 0))
    }
}
#endif
