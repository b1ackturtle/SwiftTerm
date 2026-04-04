//
//  UnicodeTests.swift
//  
// Tests for assorted rendering capabilities
//
#if os(macOS)
import Foundation
import Testing

@testable import SwiftTerm

@Suite(.serialized)
final class SwiftTermUnicode {
    
    @Test func testCombiningCharacters() {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        
        let t = h.terminal!
        // Feed combining characters:
        // "Λ" and COMBINING RING ABOVE to produce the single character Λ̊
        // "v" and COMBINING DOT ABOVE
        // "r" and COMBINING DIAERESIS
        // "a" and COMBINING RIGHT HARPOON ABOVE
        //
        t.feed (text: "\u{39b}\u{30a}\r\nv\u{307}\r\nr\u{308}\r\na\u{20d1}\r\nb\u{20d1}")
        
        #expect(t.getCharacter (col:0, row: 0) == "Λ̊")
        #expect(t.getCharacter (col:0, row: 1) == "v̇")
        #expect(t.getCharacter (col:0, row: 2) == "r̈")
        #expect(t.getCharacter (col:0, row: 3) == "a⃑")
        #expect(t.getCharacter (col:0, row: 4) == "b⃑")
        
    }

    @Test func testVariationSelector() {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        // This will send ⛩️ (0x26e9) is actually in a special class: it can either be one-column (⛩) or two-columns (⛩️)
        // depending on the unicode "variation selector" that follows: 0x26e9 0xfe0e = ⛩, 0x26e9 0xfe0f = ⛩️.
        // Globally, any unicode character followed by 0xfe0e will be single column, any unicode character
        // followed by 0xfe0f will be double-column:
        // https://en.wikipedia.org/wiki/Variation_Selectors_(Unicode_block)
        //
        // The first line is the unicode with the double-size modifier
        // The second line is the unicode character but we are forcing single column
        // The third line is the default
        t.feed (text: "\u{026e9}\u{0fe0f}\n\r\u{026e9}\u{0fe0e}\n\r\u{026e9}")

        // The first line should have 2 columns
        let char0_0 = t.getCharData(col: 0, row: 0)
        #expect(char0_0?.width == 2)

        // The second line should have 1 columns
        let char1_0 = t.getCharData(col: 0, row: 1)
        #expect(char1_0?.width == 1)

        // The third line should have 1 columns
        let char2_0 = t.getCharData(col: 0, row: 2)
        #expect(char2_0?.width == 1)
    }

    @Test func testCombinedPositioning() {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        // Baseline, we know that "\u{1100}" will always use 2-columns
        // This inserts a simple 2-column value, and then a 1-column value
        t.feed (text: "\u{1100}x\n\r")
        let char0_0 = t.getCharacter (col: 0, row: 0)
        let char1_0 = t.getCharacter (col: 1, row: 0)
        let char2_0 = t.getCharacter (col: 2, row: 0)
        #expect(char0_0 == "\u{1100}")
        #expect(char1_0 == "\u{0}")
        #expect(char2_0 == "x")

        // Here we insert a value that upgrades from 1-column to 2-column when we see the
        // \u{fe0f}, so we need to make sure that the character after that has its position updated.
        t.feed (text: "\u{026e9}\u{0fe0f}x")
        let char0_1 = t.getCharacter (col: 0, row: 1)
        let char1_1 = t.getCharacter (col: 1, row: 1)
        let char2_1 = t.getCharacter (col: 2, row: 1)
        //print("Got \(char0_1) \(char1_1) \(char2_1)")
        #expect(char0_1 == "\u{026e9}\u{0fe0f}")
        #expect(char1_1 == "\u{0}")
        #expect(char2_1 == "x")

    }

    @Test func testEmoji() {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        // This sends emoji with skin tone modifiers
        // The base emoji and skin tone modifier should combine into a single character
        t.feed (text: "👦🏻x\r\n👦🏿x\r\n")

        let char0_0 = t.getCharacter (col:0, row: 0)
        let char1_0 = t.getCharacter (col:1, row: 0)
        let char2_0 = t.getCharacter (col:2, row: 0)

        let char0_1 = t.getCharacter (col:0, row: 1)
        let char1_1 = t.getCharacter (col:1, row: 1)
        let char2_1 = t.getCharacter (col:2, row: 1)

        // Emoji with skin tone modifiers should be combined into a single grapheme cluster
        #expect(char0_0 == "👦🏻")
        #expect(char1_0 == "\u{0}")
        #expect(char2_0 == "x")
        #expect(char0_1 == "👦🏿")
        #expect(char1_1 == "\u{0}")
        #expect(char2_1 == "x")
    }

    @Test func testEmojiWithModifierBase() {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        // Test hand emoji with skin tone (as reported in issue #341)
        // 🖐️ (raised hand) + skin tone modifier should combine
        t.feed (text: "🖐🏾\r\n")

        let char0_0 = t.getCharacter (col:0, row: 0)

        // The hand emoji and skin tone should combine into single grapheme cluster
        #expect(char0_0 == "🖐🏾")
    }

    @Test func testEmojiZWJSequence() {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        // Test ZWJ (Zero Width Joiner) emoji sequences
        // Family emoji: 👩‍👩‍👦‍👦 = 👩 + ZWJ + 👩 + ZWJ + 👦 + ZWJ + 👦
        t.feed (text: "👩‍👩‍👦‍👦\r\n")

        let char0_0 = t.getCharacter (col:0, row: 0)

        // The entire ZWJ sequence should combine into a single grapheme cluster
        #expect(char0_0 == "👩‍👩‍👦‍👦")
    }

    @Test func testEmojiZWJSequenceSimple() {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        // Test simpler ZWJ sequence: couple with heart 👩‍❤️‍👨
        t.feed (text: "👩‍❤️‍👨\r\n")

        let char0_0 = t.getCharacter (col:0, row: 0)

        #expect(char0_0 == "👩‍❤️‍👨")
    }

    @Test func testCJKCharacterPositioning ()
    {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        // Test Japanese hiragana (double-width characters)
        // Each character should occupy 2 columns
        t.feed (text: "あいう")

        // Verify character positions
        #expect(t.getCharacter(col: 0, row: 0) == "あ")
        #expect(t.getCharacter(col: 1, row: 0) == "\u{0}")  // placeholder
        #expect(t.getCharacter(col: 2, row: 0) == "い")
        #expect(t.getCharacter(col: 3, row: 0) == "\u{0}")  // placeholder
        #expect(t.getCharacter(col: 4, row: 0) == "う")
        #expect(t.getCharacter(col: 5, row: 0) == "\u{0}")  // placeholder

        // Verify character widths
        #expect(t.getCharData(col: 0, row: 0)?.width == 2)
        #expect(t.getCharData(col: 2, row: 0)?.width == 2)
        #expect(t.getCharData(col: 4, row: 0)?.width == 2)

        // Cursor should be at column 6 after 3 double-width characters
        #expect(t.buffer.x == 6)
    }

    @Test func testCJKMixedWithAscii ()
    {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        // Test mixed ASCII and CJK characters
        t.feed (text: "aあbいc")

        // 'a' at col 0 (width 1)
        #expect(t.getCharacter(col: 0, row: 0) == "a")
        #expect(t.getCharData(col: 0, row: 0)?.width == 1)

        // 'あ' at col 1 (width 2)
        #expect(t.getCharacter(col: 1, row: 0) == "あ")
        #expect(t.getCharData(col: 1, row: 0)?.width == 2)

        // 'b' at col 3 (width 1)
        #expect(t.getCharacter(col: 3, row: 0) == "b")
        #expect(t.getCharData(col: 3, row: 0)?.width == 1)

        // 'い' at col 4 (width 2)
        #expect(t.getCharacter(col: 4, row: 0) == "い")
        #expect(t.getCharData(col: 4, row: 0)?.width == 2)

        // 'c' at col 6 (width 1)
        #expect(t.getCharacter(col: 6, row: 0) == "c")
        #expect(t.getCharData(col: 6, row: 0)?.width == 1)

        // Cursor should be at column 7
        #expect(t.buffer.x == 7)
    }

    @Test func testChineseCharacterPositioning ()
    {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        // Test Chinese characters (also double-width)
        t.feed (text: "中文字")

        #expect(t.getCharacter(col: 0, row: 0) == "中")
        #expect(t.getCharacter(col: 2, row: 0) == "文")
        #expect(t.getCharacter(col: 4, row: 0) == "字")

        // All should be width 2
        #expect(t.getCharData(col: 0, row: 0)?.width == 2)
        #expect(t.getCharData(col: 2, row: 0)?.width == 2)
        #expect(t.getCharData(col: 4, row: 0)?.width == 2)

        #expect(t.buffer.x == 6)
    }
    @Test func testZwJSequencePreservesVariationSelector16() {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        let sequence = "👩‍❤\u{FE0F}"
        t.feed (text: "\(sequence)\r\n")

        let cell = t.getCharacter (col:0, row: 0)
        #expect(cell != nil)
        let char0_0 = cell ?? " "
        #expect(char0_0.unicodeScalars.contains { $0.value == 0xFE0F })
    }

    @Test func testZwJSequencePreservesVariationSelector15() {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        let sequence = "👩‍❤\u{FE0E}"
        t.feed (text: "\(sequence)\r\n")

        let cell = t.getCharacter (col:0, row: 0)
        #expect(cell != nil)
        let char0_0 = cell ?? " "
        #expect(char0_0.unicodeScalars.contains { $0.value == 0xFE0E })
    }

    @Test func testBufferTranslationUsesCharacterProviderForExtendedGrapheme() {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        let sequence = "👩‍👩‍👦‍👦"
        t.feed (text: "\(sequence)X")

        let line = t.buffer.translateBufferLineToString(
            lineIndex: t.buffer.yDisp,
            trimRight: true,
            startCol: 0,
            endCol: -1,
            skipNullCellsFollowingWide: true,
            characterProvider: { t.getCharacter(for: $0) }
        ).replacingOccurrences(of: "\u{0}", with: " ")

        #expect(line == "\(sequence)X")
    }

    @Test func testNoBreakSpaceWidth() {
        let h = HeadlessTerminal (queue: SwiftTermTests.queue) { exitCode in }
        let t = h.terminal!

        // Test NO-BREAK SPACE (U+00A0) positioning
        // NBSP should have width 1, same as regular space
        // This is important for applications like Claude Code that use NBSP after prompt
        t.feed (text: ">\u{00A0}x")  // > + NBSP + x

        // '>' at col 0 (width 1)
        #expect(t.getCharacter(col: 0, row: 0) == ">")
        #expect(t.getCharData(col: 0, row: 0)?.width == 1)

        // NBSP at col 1 (width 1, NOT -1)
        #expect(t.getCharacter(col: 1, row: 0) == "\u{00A0}")
        #expect(t.getCharData(col: 1, row: 0)?.width == 1)

        // 'x' at col 2 (width 1)
        #expect(t.getCharacter(col: 2, row: 0) == "x")
        #expect(t.getCharData(col: 2, row: 0)?.width == 1)

        // Cursor should be at column 3
        #expect(t.buffer.x == 3)
    }

    // MARK: - Unicode Tests Ported from Ghostty

    /// Test VS15 (text presentation) makes wide character narrow
    /// From Ghostty: "Terminal: VS15 to make narrow character"
    @Test func testVS15MakesWideCharNarrow() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Umbrella with rain drops (☔) - typically width 2
        // followed by VS15 (U+FE0E) to make it narrow (width 1)
        t.feed(text: "\u{2614}\u{FE0E}x")

        // With VS15, the umbrella should be width 1
        let umbrellaCell = t.getCharData(col: 0, row: 0)
        #expect(umbrellaCell?.width == 1)

        // 'x' should be at col 1 (not col 2)
        let xChar = t.getCharacter(col: 1, row: 0)
        #expect(xChar == "x")
    }

    /// Test VS15 on already narrow emoji doesn't change width
    /// From Ghostty: "Terminal: VS15 on already narrow emoji"
    @Test func testVS15OnAlreadyNarrowEmoji() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Thunder cloud and rain (⛈) - width 1 by default
        // VS15 should keep it at width 1
        t.feed(text: "\u{26C8}\u{FE0E}x")

        let cloudCell = t.getCharData(col: 0, row: 0)
        #expect(cloudCell?.width == 1)

        // 'x' should be at col 1
        #expect(t.getCharacter(col: 1, row: 0) == "x")
    }

    /// Test VS16 (emoji presentation) makes narrow character wide
    /// From Ghostty: "Terminal: VS16 to make wide character with mode 2027"
    @Test func testVS16MakesNarrowCharWide() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Heart (❤) - can be narrow or wide
        // VS16 (U+FE0F) should make it width 2
        t.feed(text: "\u{2764}\u{FE0F}x")

        let heartCell = t.getCharData(col: 0, row: 0)
        #expect(heartCell?.width == 2)

        // 'x' should be at col 2 (after the wide heart)
        #expect(t.getCharacter(col: 2, row: 0) == "x")
    }

    @Test func testUnicodeUtilCharacterWidthsMatchImeOverlayNeeds() {
        #expect(UnicodeUtil.columnWidth(character: "☀️") == 2)
        #expect(UnicodeUtil.columnWidth(character: "❤️") == 2)
        #expect(UnicodeUtil.columnWidth(character: "1️⃣") == 2)
        #expect(UnicodeUtil.columnWidth(character: "1\u{FE0E}\u{20E3}") == 1)
        #expect(UnicodeUtil.columnWidth(character: "a\u{20D1}") == 1)
    }

    /// Test invalid VS15 following emoji that doesn't support it stays wide
    /// From Ghostty: "Terminal: print invalid VS15 following emoji is wide"
    @Test func testInvalidVS15EmojiStaysWide() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Brain emoji (🧠) doesn't support VS15
        // It should remain width 2
        t.feed(text: "\u{1F9E0}\u{FE0E}x")

        let brainCell = t.getCharData(col: 0, row: 0)
        #expect(brainCell?.width == 2)

        // 'x' should be at col 2
        #expect(t.getCharacter(col: 2, row: 0) == "x")
    }

    /// Test VS15 in ZWJ sequence (invalid placement) is handled
    /// From Ghostty: "Terminal: print invalid VS15 in emoji ZWJ sequence"
    @Test func testInvalidVS15InZWJSequence() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Woman emoji + invalid VS15 + ZWJ + Boy emoji
        // The sequence should still render as a combined character
        t.feed(text: "\u{1F469}\u{FE0E}\u{200D}\u{1F466}x")

        // The combined emoji should be width 2
        let emojiCell = t.getCharData(col: 0, row: 0)
        #expect(emojiCell?.width == 2)
    }

    /// Test multiple Fitzpatrick skin tone modifiers
    /// From Ghostty: comprehensive skin tone testing
    @Test func testFitzpatrickModifiers() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Thumbs up with different skin tones
        // 🏻 Light, 🏼 Medium-Light, 🏽 Medium, 🏾 Medium-Dark, 🏿 Dark
        t.feed(text: "👍🏻\r\n👍🏼\r\n👍🏽\r\n👍🏾\r\n👍🏿\r\n")

        // All should be combined into single grapheme clusters
        #expect(t.getCharacter(col: 0, row: 0) == "👍🏻")
        #expect(t.getCharacter(col: 0, row: 1) == "👍🏼")
        #expect(t.getCharacter(col: 0, row: 2) == "👍🏽")
        #expect(t.getCharacter(col: 0, row: 3) == "👍🏾")
        #expect(t.getCharacter(col: 0, row: 4) == "👍🏿")

        // All should be width 2
        #expect(t.getCharData(col: 0, row: 0)?.width == 2)
        #expect(t.getCharData(col: 0, row: 1)?.width == 2)
        #expect(t.getCharData(col: 0, row: 2)?.width == 2)
        #expect(t.getCharData(col: 0, row: 3)?.width == 2)
        #expect(t.getCharData(col: 0, row: 4)?.width == 2)
    }

    /// Test flag emoji (regional indicator symbols)
    /// From Ghostty: regional indicator handling
    @Test func testFlagEmoji() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // US flag: 🇺🇸 = U+1F1FA (Regional Indicator U) + U+1F1F8 (Regional Indicator S)
        t.feed(text: "\u{1F1FA}\u{1F1F8}x")

        let flagData = t.getCharData(col: 0, row: 0)
        #expect(flagData?.width == 2)

        let flagChar = t.getCharacter(col: 0, row: 0)
        #expect(flagChar == "🇺🇸")

        // 'x' should be at column 2 (flag takes 2 cells)
        let xChar = t.getCharacter(col: 2, row: 0)
        #expect(xChar == "x")
    }

    /// Test multiple flag emoji in sequence
    @Test func testMultipleFlagEmoji() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // US flag followed by GB flag: 🇺🇸🇬🇧
        t.feed(text: "\u{1F1FA}\u{1F1F8}\u{1F1EC}\u{1F1E7}x")

        // First flag at col 0
        #expect(t.getCharacter(col: 0, row: 0) == "🇺🇸")
        #expect(t.getCharData(col: 0, row: 0)?.width == 2)

        // Second flag at col 2
        #expect(t.getCharacter(col: 2, row: 0) == "🇬🇧")
        #expect(t.getCharData(col: 2, row: 0)?.width == 2)

        // 'x' at col 4
        #expect(t.getCharacter(col: 4, row: 0) == "x")
    }

    /// Test odd number of regional indicators (3 RIs = one flag + one unpaired RI)
    @Test func testOddRegionalIndicators() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Three RIs: U+1F1FA + U+1F1F8 + U+1F1EC + 'x'
        // Should produce: 🇺🇸 (flag) + 🇬 (unpaired RI) + x
        t.feed(text: "\u{1F1FA}\u{1F1F8}\u{1F1EC}x")

        // First two RIs combine into US flag at col 0
        #expect(t.getCharacter(col: 0, row: 0) == "🇺🇸")
        #expect(t.getCharData(col: 0, row: 0)?.width == 2)

        // Third RI is unpaired at col 2, width 2
        let thirdChar = t.getCharacter(col: 2, row: 0)
        #expect(thirdChar == "\u{1F1EC}")
        #expect(t.getCharData(col: 2, row: 0)?.width == 2)

        // 'x' at col 4
        #expect(t.getCharacter(col: 4, row: 0) == "x")
    }

    /// Test keycap emoji sequences (digit + VS16 + combining enclosing keycap)
    /// From Ghostty: keycap sequence handling
    @Test func testKeycapEmoji() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Keycap 1: 1️⃣ = '1' + VS16 + U+20E3 (Combining Enclosing Keycap)
        t.feed(text: "1\u{FE0F}\u{20E3}x")

        // The keycap should be a single grapheme cluster
        let keycapChar = t.getCharacter(col: 0, row: 0)
        #expect(keycapChar?.unicodeScalars.contains { $0 == "1" } == true)

        // Keycap should be width 2 (with VS16)
        #expect(t.getCharData(col: 0, row: 0)?.width == 2)
    }

    /// Test keycap with VS15 (text style, narrow)
    /// From Ghostty: "Terminal: keypad sequence VS15"
    @Test func testKeycapEmojiVS15() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Keycap with VS15: '1' + VS15 + U+20E3
        // Should be narrow (width 1)
        t.feed(text: "1\u{FE0E}\u{20E3}x")

        let keycapChar = t.getCharacter(col: 0, row: 0)
        #expect(keycapChar != nil)

        // With VS15, should be width 1
        #expect(t.getCharData(col: 0, row: 0)?.width == 1)

        // 'x' should be at col 1
        #expect(t.getCharacter(col: 1, row: 0) == "x")
    }

    /// Test tag sequences (e.g., subdivision flags)
    /// From Ghostty: tag sequence handling
    @Test func testTagSequenceFlags() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Scotland flag: 🏴󠁧󠁢󠁳󠁣󠁴󠁿 = black flag + tag_g + tag_b + tag_s + tag_c + tag_t + cancel_tag
        t.feed(text: "🏴󠁧󠁢󠁳󠁣󠁴󠁿x")

        // Should be a single grapheme cluster
        let flagChar = t.getCharacter(col: 0, row: 0)
        #expect(flagChar != nil)

        // Should be width 2
        #expect(t.getCharData(col: 0, row: 0)?.width == 2)
    }

    /// Test multiple combining characters on single base
    /// From Ghostty: grapheme cluster handling
    @Test func testMultipleCombiningCharacters() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // 'e' with multiple combining diacriticals
        // e + acute + tilde = ḗ (approximately)
        t.feed(text: "e\u{0301}\u{0303}x")

        // Should combine into single grapheme
        let combinedChar = t.getCharacter(col: 0, row: 0)
        #expect(combinedChar?.unicodeScalars.count == 3)

        // Should be width 1
        #expect(t.getCharData(col: 0, row: 0)?.width == 1)

        // 'x' should be at col 1
        #expect(t.getCharacter(col: 1, row: 0) == "x")
    }

    /// Test emoji with multiple modifiers (skin tone + ZWJ + profession)
    /// From Ghostty: complex ZWJ sequences
    @Test func testComplexEmojiZWJWithModifiers() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Woman technologist with skin tone: 👩🏻‍💻
        t.feed(text: "👩🏻‍💻x")

        // Should be single grapheme cluster
        let emojiChar = t.getCharacter(col: 0, row: 0)
        #expect(emojiChar == "👩🏻‍💻")

        // Should be width 2
        #expect(t.getCharData(col: 0, row: 0)?.width == 2)

        // 'x' should be at col 2
        #expect(t.getCharacter(col: 2, row: 0) == "x")
    }

    /// Test Korean Hangul syllable blocks (composed characters)
    /// From Ghostty: Korean character handling
    @Test func testKoreanHangul() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Korean text: 한글 (Hangul)
        t.feed(text: "한글x")

        // Each Hangul syllable should be width 2
        #expect(t.getCharacter(col: 0, row: 0) == "한")
        #expect(t.getCharData(col: 0, row: 0)?.width == 2)
        #expect(t.getCharacter(col: 2, row: 0) == "글")
        #expect(t.getCharData(col: 2, row: 0)?.width == 2)
        #expect(t.getCharacter(col: 4, row: 0) == "x")
    }

    /// Test that overwriting wide character clears spacer cell
    /// From Ghostty: wide character overwrite handling
    @Test func testOverwriteWideCharacter() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Write a wide character
        t.feed(text: "あ")
        #expect(t.getCharacter(col: 0, row: 0) == "あ")
        #expect(t.getCharData(col: 0, row: 0)?.width == 2)

        // Move cursor back and overwrite with narrow character
        t.feed(text: "\u{1b}[1Gx")  // Move to col 1, write 'x'

        // The wide character should be replaced
        #expect(t.getCharacter(col: 0, row: 0) == "x")
        #expect(t.getCharData(col: 0, row: 0)?.width == 1)
        #expect(t.getCharData(col: 1, row: 0)?.code == 0)
        #expect(t.getCharData(col: 1, row: 0)?.width == 1)
    }

    @Test func testOverwriteWideCharacterFromTrailingCell() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "あ")
        t.feed(text: "\u{1b}[2Gx")  // Move to the wide character's trailing cell, then overwrite

        #expect(t.getCharacter(col: 0, row: 0) == "x")
        #expect(t.getCharData(col: 0, row: 0)?.width == 1)
        #expect(t.getCharData(col: 1, row: 0)?.code == 0)
        #expect(t.getCharData(col: 1, row: 0)?.width == 1)
        #expect(t.buffer.x == 1)
    }

    @Test func testBackspaceEraseAfterEmojiVariationSequence() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "\u{2600}\u{FE0F}\u{08} \u{08}")

        // After BS+SP+BS on a wide emoji, the space overwrites the leading cell
        // and the trailing cell is cleared to null.
        #expect(t.getCharacter(col: 0, row: 0) == " ")
        #expect(t.getCharData(col: 0, row: 0)?.width == 1)
        #expect(t.getCharData(col: 1, row: 0)?.code == 0)
        #expect(t.getCharData(col: 1, row: 0)?.width == 1)
        #expect(t.buffer.x == 0)
    }

    @Test func testBackspaceEraseAfterEmojiVariationSequenceAcrossSeparateFeeds() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "\u{2600}\u{FE0F}")
        t.feed(text: "\u{08}")
        t.feed(text: " ")
        t.feed(text: "\u{08}")

        // After BS+SP+BS the wide character is cleared: space at leading cell, null at trailing
        #expect(t.getCharacter(col: 0, row: 0) == " ")
        #expect(t.getCharData(col: 0, row: 0)?.width == 1)
        #expect(t.getCharData(col: 1, row: 0)?.code == 0)
        #expect(t.getCharData(col: 1, row: 0)?.width == 1)
        #expect(t.buffer.x == 0)

        let bufferLine = t.buffer.lines[t.buffer.y + t.buffer.yBase]
        guard let resolved = t.resolvedWideCell(in: bufferLine, at: t.buffer.x) else {
            Issue.record("Expected erased cell to resolve")
            return
        }
        guard let cursor = t.resolvedCursorCell(in: bufferLine, at: t.buffer.x) else {
            Issue.record("Expected erased cell to resolve to a cursor cell")
            return
        }

        #expect(resolved.col == 0)
        #expect(t.getCharacter(for: resolved.cell) == " ")
        #expect(resolved.cell.width == 1)
        #expect(cursor.col == 0)
        #expect(cursor.renderWidth == 1)
    }

    @Test func testTypingAfterWideErasePlaceholderOverwritesWholeSlot() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "\u{2600}\u{FE0F}")
        t.feed(text: "\u{08}")
        t.feed(text: " ")
        t.feed(text: "\u{08}")
        t.feed(text: "a")

        #expect(t.getCharacter(col: 0, row: 0) == "a")
        #expect(t.getCharData(col: 0, row: 0)?.width == 1)
        #expect(t.getCharData(col: 1, row: 0)?.code == 0)
        #expect(t.getCharData(col: 1, row: 0)?.width == 1)
        #expect(t.buffer.x == 1)
    }

    @Test func testBackspaceEraseAfterWideCharacterAcrossSeparateFeeds() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "あ")
        t.feed(text: "\u{08}")
        t.feed(text: " ")
        t.feed(text: "\u{08}")

        #expect(t.getCharacter(col: 0, row: 0) == " ")
        #expect(t.getCharData(col: 0, row: 0)?.width == 1)
        #expect(t.getCharData(col: 1, row: 0)?.code == 0)
        #expect(t.getCharData(col: 1, row: 0)?.width == 1)
        #expect(t.buffer.x == 0)

        let line = t.buffer.lines[t.buffer.y + t.buffer.yBase]
        guard let cursor = t.resolvedCursorCell(in: line, at: t.buffer.x) else {
            Issue.record("Expected erased wide character to resolve to a cursor cell")
            return
        }

        #expect(cursor.col == 0)
        #expect(cursor.renderWidth == 1)
    }

    @Test func testResolvedWideCellUsesLeaderForTrailingCell() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "\u{2600}\u{FE0F}")

        let line = t.buffer.lines[t.buffer.y + t.buffer.yBase]
        guard let resolved = t.resolvedWideCell(in: line, at: 1) else {
            Issue.record("Expected trailing cell to resolve to wide leader")
            return
        }

        #expect(resolved.col == 0)
        #expect(t.getCharacter(for: resolved.cell) == "\u{2600}\u{FE0F}")
        #expect(resolved.cell.width == 2)

        guard let cursor = t.resolvedCursorCell(in: line, at: 1) else {
            Issue.record("Expected live wide cell to resolve to a wide cursor span")
            return
        }

        #expect(cursor.col == 0)
        #expect(cursor.renderWidth == 2)
    }

    @Test func testBackspaceStepsOverVs16WideGlyphAsSingleUnit() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "a\u{2600}\u{FE0F}")
        #expect(t.buffer.x == 3)

        t.feed(text: "\u{08}")

        #expect(t.buffer.x == 1)
    }

    @Test func testCursorBackwardStepsOverVs16WideGlyphAsSingleUnit() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "a\u{2600}\u{FE0F}")
        #expect(t.buffer.x == 3)

        t.feed(text: "\u{1b}[1D")

        #expect(t.buffer.x == 1)
    }

    @Test func testCursorForwardStepsOverVs16WideGlyphAsSingleUnit() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "a\u{2600}\u{FE0F}")
        t.feed(text: "\u{1b}[1D")
        #expect(t.buffer.x == 1)

        t.feed(text: "\u{1b}[1C")

        #expect(t.buffer.x == 3)
    }

    @Test func testBackspaceKeepsCellwiseMovementForCjkWideGlyph() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "aあ")
        #expect(t.buffer.x == 3)

        t.feed(text: "\u{08}")

        #expect(t.buffer.x == 2)
    }

    @Test func testZshStyleRedrawAfterVs16EmojiDeleteDoesNotDuplicatePrefix() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "a\u{2600}\u{FE0F}")
        let redraw: [UInt8] = [0x08, 0x08, 0x1b, 0x5b, 0x32, 0x37, 0x6d, 0x61, 0x1b, 0x5b, 0x32, 0x37, 0x6d, 0x20, 0x08]
        t.feed(buffer: redraw[...])

        #expect(t.getCharacter(col: 0, row: 0) == "a")
        #expect(t.getCharacter(col: 1, row: 0) == " ")
        #expect(t.getCharData(col: 2, row: 0)?.code == 0)
        #expect(t.buffer.x == 1)
    }

    @Test func testZshStyleRedrawAfterVs16EmojiDeleteWithTwoAsciiPrefixes() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "aa\u{2600}\u{FE0F}")
        let redraw: [UInt8] = [0x08, 0x1b, 0x5b, 0x32, 0x37, 0x6d, 0x1b, 0x5b, 0x32, 0x37, 0x6d, 0x20, 0x08]
        t.feed(buffer: redraw[...])

        #expect(t.getCharacter(col: 0, row: 0) == "a")
        #expect(t.getCharacter(col: 1, row: 0) == "a")
        #expect(t.getCharacter(col: 2, row: 0) == " ")
        #expect(t.buffer.x == 2)
    }

    @Test func testZshStyleRedrawAfterMidLineVs16DeleteCollapsesSuffix() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "aaa\u{2600}\u{FE0F}aaa")
        t.feed(text: "\u{1b}[D\u{1b}[D\u{1b}[D")
        #expect(t.buffer.x == 5)

        let redraw: [UInt8] = [0x08, 0x61, 0x1b, 0x5b, 0x32, 0x43, 0x20, 0x08, 0x08, 0x08, 0x08]
        t.feed(buffer: redraw[...])

        #expect(t.getCharacter(col: 0, row: 0) == "a")
        #expect(t.getCharacter(col: 1, row: 0) == "a")
        #expect(t.getCharacter(col: 2, row: 0) == "a")
        #expect(t.getCharacter(col: 3, row: 0) == "a")
        #expect(t.getCharacter(col: 4, row: 0) == "a")
        #expect(t.getCharacter(col: 5, row: 0) == "a")
        #expect(t.getCharacter(col: 6, row: 0) == " ")
        #expect(t.buffer.x == 3)
    }

    @Test func testZshStyleSecondBackspaceAfterMidLineVs16DeleteKeepsSuffixCollapsed() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "aaa\u{2600}\u{FE0F}aaa")
        t.feed(text: "\u{1b}[D\u{1b}[D\u{1b}[D")
        let firstDelete: [UInt8] = [0x08, 0x61, 0x1b, 0x5b, 0x32, 0x43, 0x20, 0x08, 0x08, 0x08, 0x08]
        t.feed(buffer: firstDelete[...])

        let secondDelete: [UInt8] = [0x1b, 0x5b, 0x32, 0x43, 0x20, 0x08, 0x08, 0x08, 0x08]
        t.feed(buffer: secondDelete[...])

        #expect(t.getCharacter(col: 0, row: 0) == "a")
        #expect(t.getCharacter(col: 1, row: 0) == "a")
        #expect(t.getCharacter(col: 2, row: 0) == "a")
        #expect(t.getCharacter(col: 3, row: 0) == "a")
        #expect(t.getCharacter(col: 4, row: 0) == "a")
        #expect(t.getCharacter(col: 5, row: 0) == " ")
        #expect(t.buffer.x == 2)
    }

    @Test func testZshStyleRedrawAfterAsciiDeleteBeforeVs16AndCjkSuffixKeepsCursorAligned() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "aiueo\u{2600}\u{FE0F}あいうえお")
        t.feed(text: "\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D")
        #expect(t.buffer.x == 5)

        let redraw: [UInt8] = [0x08, 0x1b, 0x5b, 0x50, 0x1b, 0x5b, 0x31, 0x31, 0x43, 0x20, 0x1b, 0x5b, 0x31, 0x32, 0x44]
        t.feed(buffer: redraw[...])

        #expect(t.getCharacter(col: 0, row: 0) == "a")
        #expect(t.getCharacter(col: 1, row: 0) == "i")
        #expect(t.getCharacter(col: 2, row: 0) == "u")
        #expect(t.getCharacter(col: 3, row: 0) == "e")
        #expect(t.getCharacter(col: 4, row: 0) == "\u{2600}\u{FE0F}")
        #expect(t.getCharacter(col: 6, row: 0) == "あ")
        #expect(t.getCharacter(col: 8, row: 0) == "い")
        #expect(t.getCharacter(col: 10, row: 0) == "う")
        #expect(t.getCharacter(col: 12, row: 0) == "え")
        #expect(t.getCharacter(col: 14, row: 0) == "お")
        #expect(t.buffer.x == 4)
    }

    @Test func testVs16RewriteAfterLineStartInsertKeepsAsciiPrefixVisible() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "aiueo")
        t.feed(text: "\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D")

        let initialInsert: [UInt8] = [
            0x1b, 0x5b, 0x37, 0x6d,
            0xE2, 0x98, 0x80, 0xEF, 0xB8, 0x8F,
            0x1b, 0x5b, 0x32, 0x37, 0x6d,
            0x61, 0x69, 0x75, 0x65, 0x6f,
            0x08, 0x08, 0x08, 0x08, 0x08
        ]
        t.feed(buffer: initialInsert[...])

        #expect(t.getText(start: Position(col: 0, row: 0), end: Position(col: 12, row: 0)) == "☀️aiueo")
        #expect(t.buffer.x == 2)

        let rightArrowRedraw: [UInt8] = [
            0x08,
            0x1b, 0x5b, 0x32, 0x37, 0x6d,
            0xE2, 0x98, 0x80, 0xEF, 0xB8, 0x8F,
            0x1b, 0x5b, 0x31, 0x43
        ]
        t.feed(buffer: rightArrowRedraw[...])

        #expect(t.getText(start: Position(col: 0, row: 0), end: Position(col: 12, row: 0)) == "☀️aiueo")
        #expect(t.buffer.x == 3)
    }

    @Test func testImeVs16RewriteAfterLineStartInsertKeepsAsciiPrefixVisible() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "aiueo")
        t.feed(text: "\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D")

        let imeChunk1: [UInt8] = [
            0xE2, 0x98, 0x80,
            0x61, 0x69, 0x75, 0x65, 0x6F,
            0x08, 0x08, 0x08, 0x08, 0x08
        ]
        t.feed(buffer: imeChunk1[...])

        #expect(t.getText(start: Position(col: 0, row: 0), end: Position(col: 12, row: 0)) == "☀aiueo")
        #expect(t.buffer.x == 1)

        let imeChunk2: [UInt8] = [0x08, 0xE2, 0x98, 0x80, 0xEF, 0xB8, 0x8F]
        t.feed(buffer: imeChunk2[...])

        #expect(t.getText(start: Position(col: 0, row: 0), end: Position(col: 12, row: 0)) == "☀️aiueo")
        #expect(t.buffer.x == 2)
    }

    @Test func testCtrlKStyleEraseFromLineStartClearsVs16AndAsciiSuffix() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "\u{2600}\u{FE0F}aiueo")
        t.feed(text: "\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D")
        t.feed(buffer: [0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08][...])

        #expect(t.getCharacter(col: 0, row: 0) == " ")
        #expect(t.getCharData(col: 1, row: 0)?.code == 0)
        #expect(t.getCharacter(col: 2, row: 0) == " ")
        #expect(t.getCharacter(col: 3, row: 0) == " ")
        #expect(t.getCharacter(col: 4, row: 0) == " ")
        #expect(t.getCharacter(col: 5, row: 0) == " ")
        #expect(t.getCharacter(col: 6, row: 0) == " ")
        #expect(t.buffer.x == 0)
    }

    @Test func testTypingAfterCtrlKStyleEraseDoesNotRevealStaleSuffix() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "\u{2600}\u{FE0F}aiueo")
        t.feed(text: "\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D\u{1b}[D")
        t.feed(buffer: [0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08][...])
        t.feed(text: "x")

        #expect(t.getCharacter(col: 0, row: 0) == "x")
        #expect(t.getCharData(col: 1, row: 0)?.code == 0)
        #expect(t.getCharacter(col: 2, row: 0) == " ")
        #expect(t.getCharacter(col: 6, row: 0) == " ")
        #expect(t.buffer.x == 1)
    }

    @Test func testDeleteVs16BetweenCjkRunsKeepsSuffixAligned() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        t.feed(text: "あいうえお")
        t.feed(buffer: [0xE2, 0x98, 0x80][...])
        t.feed(buffer: [0x08, 0xE2, 0x98, 0x80, 0xEF, 0xB8, 0x8F][...])
        t.feed(text: "あいうえお")
        for _ in 0..<5 {
            t.feed(buffer: [0x08, 0x08][...])
        }

        let redraw: [UInt8] = [0x08, 0x1b, 0x5b, 0x50, 0x1b, 0x5b, 0x31, 0x30, 0x43, 0x20, 0x1b, 0x5b, 0x31, 0x31, 0x44]
        t.feed(buffer: redraw[...])

        #expect(t.getCharacter(col: 0, row: 0) == "あ")
        #expect(t.getCharacter(col: 2, row: 0) == "い")
        #expect(t.getCharacter(col: 4, row: 0) == "う")
        #expect(t.getCharacter(col: 6, row: 0) == "え")
        #expect(t.getCharacter(col: 8, row: 0) == "お")
        #expect(t.getCharacter(col: 10, row: 0) == "あ")
        #expect(t.getCharacter(col: 12, row: 0) == "い")
        #expect(t.getCharacter(col: 14, row: 0) == "う")
        #expect(t.getCharacter(col: 16, row: 0) == "え")
        #expect(t.getCharacter(col: 18, row: 0) == "お")
        #expect(t.buffer.x == 10)
    }

    /// Test wide character at end of line wraps correctly
    /// From Ghostty: wide character wrapping at line end
    @Test func testWideCharacterWrapping() {
        let h = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in }
        let t = h.terminal!

        // Use a narrow terminal
        let cols = t.cols

        // Fill line to leave only 1 cell, then insert wide character
        let fillCount = cols - 1
        let fill = String(repeating: "x", count: fillCount)
        t.feed(text: fill)
        t.feed(text: "あ")  // Wide character that needs 2 cells

        // Wide character should wrap to next line since it needs 2 cells
        // but only 1 is available
        #expect(t.getCharacter(col: 0, row: 1) == "あ")
        #expect(t.buffer.y == 1)  // Should be on second line
    }

}
#endif
