// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import ObjectiveC
import Testing

/// Tests that the Objective-C runtime can realize every class in the SDK.
///
/// The Objective-C class list includes Swift classes regardless of their `@available` annotations,
/// and `objc_copyClassList` realizes every class in it. Realizing a class crashes if one of its
/// stored properties has a type that's unavailable on the running OS version and whose layout isn't
/// known at compile time. Apps and libraries (for example, Realm) call `objc_copyClassList` at
/// launch, so this crash affects apps that don't use the class.
struct ObjectiveCClassEnumerationTests {
  @Test
  func enumeratingObjectiveCClassesDoesNotCrash() throws {
    var classCount: UInt32 = 0

    // Don't read the elements as `AnyClass`; doing so retains each class, and some private root
    // classes (for example, `__NSGenericDeallocHandler`) don't implement `retain`.
    let classList = try #require(objc_copyClassList(&classCount))
    free(UnsafeMutableRawPointer(classList))

    #expect(classCount > 0)
  }
}
