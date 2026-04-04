#if os(macOS)
import AppKit
import Testing

@testable import SwiftTerm

@Suite(.serialized)
final class MacControlKeyTests {
    @Test func testControlBytePassesThroughRawControlCharacters() {
        #expect(TerminalView.controlByte(forEventCharacters: "d") == 0x04)
        #expect(TerminalView.controlByte(forEventCharacters: "\u{4}") == 0x04)
        #expect(TerminalView.controlByte(forEventCharacters: "\u{1b}") == 0x1b)
        #expect(TerminalView.controlByte(forEventCharacters: "\u{7f}") == 0x7f)
    }

    @Test func testDeleteForwardCommandKindTreatsControlDAsEof() {
        #expect(TerminalView.deleteForwardCommandKind(modifierFlags: [.control],
                                                     characters: "\u{4}",
                                                     charactersIgnoringModifiers: "d") == .eof)
        #expect(TerminalView.deleteForwardCommandKind(modifierFlags: [.control],
                                                     characters: "\u{4}",
                                                     charactersIgnoringModifiers: nil) == .eof)
        #expect(TerminalView.deleteForwardCommandKind(modifierFlags: [],
                                                     characters: nil,
                                                     charactersIgnoringModifiers: nil) == .forwardDelete)
    }
}
#endif
