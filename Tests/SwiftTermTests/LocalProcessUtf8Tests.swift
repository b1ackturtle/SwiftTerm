#if os(macOS)
import Foundation
import Testing
@testable import SwiftTerm

@Suite(.serialized)
final class LocalProcessUtf8Tests {
    private func visibleText(from terminal: Terminal) -> String {
        (0..<terminal.rows)
            .map { row in
                terminal.buffer.translateBufferLineToString(lineIndex: row,
                                                            trimRight: true,
                                                            startCol: 0,
                                                            endCol: -1,
                                                            skipNullCellsFollowingWide: true,
                                                            characterProvider: { terminal.getCharacter(for: $0) })
                    .replacingOccurrences(of: "\u{0}", with: " ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    @Test func testLocalProcessEnablesIUTF8() {
        let exitSemaphore = DispatchSemaphore(value: 0)
        let headless = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in
            exitSemaphore.signal()
        }

        headless.process.startProcess(executable: "/bin/sh", args: ["-lc", "stty -a"])

        withExtendedLifetime(headless) {
            #expect(exitSemaphore.wait(timeout: .now() + 5) == .success)
        }

        let text = visibleText(from: headless.terminal)
        #expect(text.contains("iutf8"))
        #expect(!text.contains("-iutf8"))
    }

    @Test func testCatBackspaceThenCtrlDDoesNotLeakPartialUtf8() {
        let exitSemaphore = DispatchSemaphore(value: 0)
        let headless = HeadlessTerminal(queue: SwiftTermTests.queue) { _ in
            Thread.sleep(forTimeInterval: 0.2)
            exitSemaphore.signal()
        }

        headless.process.startProcess(executable: "/bin/cat")
        Thread.sleep(forTimeInterval: 0.2)

        headless.send("☀️")
        // ☀️ is U+2600 + U+FE0F (2 code points); with IUTF8 each backspace
        // erases one code point, so we need two backspaces.
        headless.send(data: [0x7f][...])
        headless.send(data: [0x7f][...])
        headless.send(data: [0x04][...])

        withExtendedLifetime(headless) {
            #expect(exitSemaphore.wait(timeout: .now() + 5) == .success)
        }

        let text = visibleText(from: headless.terminal)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(!trimmed.contains("☀"))
        #expect(!trimmed.contains("\u{FFFD}"))
        // The terminal may show "^D" from the kernel echoing EOF — that's fine.
        let cleaned = trimmed.replacingOccurrences(of: "^D", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(cleaned.isEmpty)
    }
}
#endif
