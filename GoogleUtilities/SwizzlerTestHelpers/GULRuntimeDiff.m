// Copyright 2018 Google LLC
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

#import "GoogleUtilities/SwizzlerTestHelpers/GULRuntimeDiff.h"

#import "GoogleUtilities/SwizzlerTestHelpers/GULRuntimeClassDiff.h"

/** Computes the equality of possibly nil or empty NSSets.
 *
 *  @param firstSet The first set of strings.
 *  @param secondSet The second set of strings.
 *  @return YES if both sets are zero length or nil, or the result of `isEqualToSet:`.
 */
FOUNDATION_STATIC_INLINE
BOOL IsEqual(NSSet *firstSet, NSSet *secondSet) {
  return ((!firstSet || firstSet.count == 0) && (!secondSet || secondSet.count == 0)) ||
         [firstSet isEqualToSet:secondSet];
}

@implementation GULRuntimeDiff

- (NSUInteger)hash {
  return [_addedClasses hash] ^ [_removedClasses hash] ^ [_classDiffs hash];
}

- (BOOL)isEqual:(id)object {
  GULRuntimeDiff *otherObject = (GULRuntimeDiff *)object;
  return IsEqual(_addedClasses, otherObject->_addedClasses) &&
         IsEqual(_removedClasses, otherObject->_removedClasses) &&
         IsEqual(_classDiffs, otherObject->_classDiffs);
}

- (NSString *)description {
  NSMutableString *description = [[NSMutableString alloc] init];
  if (_addedClasses.count) {
    [description appendString:@"Added classes:\n"];
    for (NSString *classString in _addedClasses) {
      [description appendFormat:@"\t%@\n", classString];
    }
  }
  if (_removedClasses.count) {
    [description appendString:@"\nRemoved classes:\n"];
    for (NSString *classString in _removedClasses) {
      [description appendFormat:@"\t%@\n", classString];
    }
  }
  if (_classDiffs.count) {
    [description appendString:@"\nClass diffs:\n"];
    for (GULRuntimeClassDiff *classDiff in _classDiffs) {
      NSString *classDiffDescription =
          [[classDiff description] stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"];
      [description appendFormat:@"\t%@\n", classDiffDescription];
    }
  }
  return description;
}

@end
