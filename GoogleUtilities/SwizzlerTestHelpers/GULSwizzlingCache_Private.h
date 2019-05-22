/*
 * Copyright 2018 Google LLC
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

@interface GULSwizzlingCache ()

/** Checks if we've swizzled the currentIMP and returns the original IMP that would be invoked if
 *  we hadn't swizzled it in the first place. This method is private because consumers don't need it
 *  to cache or retrive any IMPs. It is used internally and for certain asserts in GULSwizzler.
 *
 *  @param currentIMP The IMP returned by class_getMethodImplementation.
 *  @return The original IMP that would be invoked if we hadn't swizzled at all, and in cases where
 *      currentIMP is not something that we put there, just returns currentIMP.
 */
+ (IMP)originalIMPOfCurrentIMP:(IMP)currentIMP;

#pragma mark - Helper methods for testing

/** Clears all the cache data structures. */
- (void)clearCache;

/** Allows tests access to the originalImps CFMutableDictionaryRef.
 *
 *  @returns the originalImps CFMutableDictionaryRef.
 */
- (CFMutableDictionaryRef)originalImps;

/** Allows tests access to the newToOriginalImps CFMutableDictionaryRef.
 *
 *  @returns the newToOriginalImps CFMutableDictionaryRef.
 */
- (CFMutableDictionaryRef)newToOriginalImps;

@end
