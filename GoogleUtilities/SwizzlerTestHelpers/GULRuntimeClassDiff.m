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

@implementation GULRuntimeClassDiff

- (NSUInteger)hash {
  return [_aClass hash] ^ [_addedClassProperties hash] ^ [_addedInstanceProperties hash] ^
         [_addedClassSelectors hash] ^ [_addedInstanceSelectors hash] ^ [_modifiedImps hash];
}

- (BOOL)isEqual:(id)object {
  GULRuntimeClassDiff *otherObject = (GULRuntimeClassDiff *)object;
  return _aClass == otherObject->_aClass &&
         IsEqual(_addedClassProperties, otherObject->_addedClassProperties) &&
         IsEqual(_addedInstanceProperties, otherObject->_addedInstanceProperties) &&
         IsEqual(_addedClassSelectors, otherObject->_addedClassSelectors) &&
         IsEqual(_addedInstanceSelectors, otherObject->_addedInstanceSelectors) &&
         IsEqual(_modifiedImps, otherObject->_modifiedImps);
}

- (NSString *)description {
  NSMutableString *description = [[NSMutableString alloc] init];
  [description appendFormat:@"%@:\n", NSStringFromClass(self.aClass)];
  if (_addedClassProperties.count) {
    [description appendString:@"\tAdded class properties:\n"];
    for (NSString *addedClassProperty in _addedClassProperties) {
      [description appendFormat:@"\t\t%@\n", addedClassProperty];
    }
  }
  if (_addedInstanceProperties.count) {
    [description appendString:@"\tAdded instance properties:\n"];
    for (NSString *addedInstanceProperty in _addedInstanceProperties) {
      [description appendFormat:@"\t\t%@\n", addedInstanceProperty];
    }
  }
  if (_addedClassSelectors.count) {
    [description appendString:@"\tAdded class selectors:\n"];
    for (NSString *addedClassSelector in _addedClassSelectors) {
      [description appendFormat:@"\t\t%@\n", addedClassSelector];
    }
  }
  if (_addedInstanceSelectors.count) {
    [description appendString:@"\tAdded instance selectors:\n"];
    for (NSString *addedInstanceSelector in _addedInstanceSelectors) {
      [description appendFormat:@"\t\t%@\n", addedInstanceSelector];
    }
  }
  if (_modifiedImps.count) {
    [description appendString:@"\tModified IMPs:\n"];
    for (NSString *modifiedImp in _modifiedImps) {
      [description appendFormat:@"\t\t%@\n", modifiedImp];
    }
  }
  return description;
}

@end
