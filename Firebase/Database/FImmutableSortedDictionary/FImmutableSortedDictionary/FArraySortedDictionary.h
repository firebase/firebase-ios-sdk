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
#import "FImmutableSortedDictionary.h"

/**
 * This is an array backed implementation of FImmutableSortedDictionary. It uses arrays and linear lookups to achieve
 * good memory efficiency while maintaining good performance for small collections. It also uses less allocations than
 * a comparable red black tree. To avoid degrading performance with increasing collection size it will automatically
 * convert to a FTreeSortedDictionary after an insert call above a certain threshold.
 */
@interface FArraySortedDictionary : FImmutableSortedDictionary

+ (FArraySortedDictionary *)fromDictionary:(NSDictionary *)dictionary withComparator:(NSComparator)comparator;

- (id)initWithComparator:(NSComparator)comparator;

#pragma mark -
#pragma mark Properties

@property (nonatomic, copy, readonly) NSComparator comparator;

@end
