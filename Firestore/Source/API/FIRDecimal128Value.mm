/*
 * Copyright 2025 Google LLC
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

#include "Firestore/Source/Public/FirebaseFirestore/FIRDecimal128Value.h"

#include "Firestore/core/src/util/quadruple.h"
#include "Firestore/core/src/util/string_apple.h"

using firebase::firestore::util::MakeString;
using firebase::firestore::util::Quadruple;

@implementation FIRDecimal128Value

- (instancetype)initWithValue:(NSString *)value {
  self = [super init];
  if (self) {
    _value = [value copy];
  }
  return self;
}

- (BOOL)isEqual:(nullable id)object {
  if (self == object) {
    return YES;
  }

  if (![object isKindOfClass:[FIRDecimal128Value class]]) {
    return NO;
  }

  FIRDecimal128Value *other = (FIRDecimal128Value *)object;

  Quadruple lhs = Quadruple();
  Quadruple rhs = Quadruple();
  lhs.Parse(MakeString(self.value));
  rhs.Parse(MakeString(other.value));

  // Firestore considers +0 and -0 to be equal, but `Quadruple::Compare()` does not.
  if (lhs.Compare(Quadruple(-0.0)) == 0) lhs = Quadruple();
  if (rhs.Compare(Quadruple(-0.0)) == 0) rhs = Quadruple();

  return lhs.Compare(rhs) == 0;
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  return [[FIRDecimal128Value alloc] initWithValue:self.value];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FIRDecimal128Value: (%@)>", self.value];
}

@end
