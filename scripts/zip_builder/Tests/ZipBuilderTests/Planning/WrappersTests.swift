/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import Testing
@testable import ZipBuilder

struct CodeFreeTests {
  @Test func commentsDirectivesAndWhitespaceAreCodeFree() {
    #expect(isCodeFree(""))
    #expect(isCodeFree("""
    // Copyright 2026 Google LLC
    /* A block
       comment. */
    #import <Foundation/Foundation.h>
      #if __has_include(<A/A.h>)
        #import <A/A.h>
      #endif
    """))
  }

  @Test func continuedDirectivesAreCodeFree() {
    #expect(isCodeFree("""
    #warning "This header is deprecated; \\
              import the module instead."
    """))
  }

  @Test func declarationsAreCode() {
    #expect(!isCodeFree("@protocol P <NSObject>\n@end"))
    #expect(!isCodeFree("#import \"a.h\"\nint x;"))
    #expect(!isCodeFree("import Foundation"))
  }

  @Test func commentMarkersInStringsAreCode() {
    #expect(removingComments(#"s = "http://example.com"; // c"#) == #"s = "http://example.com"; "#)
    #expect(!isCodeFree(#"char *s = "/* not a comment */";"#))
    #expect(removingComments("a /* x\ny */ b") == "a \n b")
  }

  @Test func emptyAndUnterminatedBlockComments() {
    #expect(removingComments("a /**/ b") == "a  b")
    #expect(removingComments("/* a */ /* b */c") == " c")
    // `/*/` opens a comment without closing it; an unclosed comment runs to the end.
    #expect(removingComments("a /*/ b") == "a ")
    #expect(removingComments("a /* x\ny") == "a \n")
    // A block comment's line breaks become `\n`.
    #expect(removingComments("a /* x\r\ny */ b") == "a \n b")
  }

  @Test func lineCommentsKeepTheirLineBreak() {
    #expect(removingComments("x // c") == "x ")
    #expect(removingComments("x // c\r\ny") == "x \r\ny")
    #expect(removingComments("x // a /* b\ny */") == "x \ny */")
  }

  @Test func slashesThatArentCommentsAreKept() {
    #expect(removingComments("a / b */ c/") == "a / b */ c/")
  }

  @Test func literalsKeepEscapesAndEndAtTheLine() {
    #expect(removingComments(#"s = 'a\'b' // c"#) == #"s = 'a\'b' "#)
    #expect(removingComments(#"s = "a\"/*b" // c"#) == #"s = "a\"/*b" "#)
    // An unterminated literal ends at the line, so comments on the next line are removed.
    #expect(removingComments("\"abc\nint x; // c") == "\"abc\nint x; ")
    // A backslash at the very end is kept.
    #expect(removingComments(#""a\"#) == #""a\"#)
  }
}
