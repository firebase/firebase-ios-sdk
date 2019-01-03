/*
 * Copyright 2018 Google
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

#include "GDLAssert.h"

GDLAssertionBlock GDLAssertionBlockToRunInsteadOfNSAssert(void) {
  // This class is only compiled in by unit tests, and this should fail quickly in optimized builds.
  Class GDLAssertClass = NSClassFromString(@"GDLAssertHelper");
  if (__builtin_expect(!!GDLAssertClass, 0)) {
    SEL assertionBlockSEL = NSSelectorFromString(@"assertionBlock");
    if (assertionBlockSEL) {
      IMP assertionBlockIMP = [GDLAssertClass methodForSelector:assertionBlockSEL];
      if (assertionBlockIMP) {
        GDLAssertionBlock assertionBlock =
            ((GDLAssertionBlock(*)(id, SEL))assertionBlockIMP)(GDLAssertClass, assertionBlockSEL);
        if (assertionBlock) {
          return assertionBlock;
        }
      }
    }
  }
  return NULL;
}
