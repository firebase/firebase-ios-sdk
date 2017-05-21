/*
 * Copyright 2017 Google
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

#import <Foundation/Foundation.h>

@interface FImmutableSortedSet : NSObject

+ (FImmutableSortedSet *)setWithKeysFromDictionary:(NSDictionary *)array comparator:(NSComparator)comparator;

- (BOOL)containsObject:(id)object;
- (FImmutableSortedSet *)addObject:(id)object;
- (FImmutableSortedSet *)removeObject:(id)object;
- (id)firstObject;
- (id)lastObject;
- (NSUInteger)count;
- (BOOL)isEmpty;

- (id)predecessorEntry:(id)entry;

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, BOOL *stop))block;
- (void)enumerateObjectsReverse:(BOOL)reverse usingBlock:(void (^)(id obj, BOOL *stop))block;

- (NSEnumerator *)objectEnumerator;

@end
