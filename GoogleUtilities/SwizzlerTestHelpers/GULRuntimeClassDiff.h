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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A simple container class for representing the diff of a class. */
@interface GULRuntimeClassDiff : NSObject

/** The class this diff is with respect to. */
@property(nonatomic, nullable, weak) Class aClass;

/** The added class properties (as opposed to instance properties). */
@property(nonatomic) NSSet<NSString *> *addedClassProperties;

/** The added instance properties. */
@property(nonatomic) NSSet<NSString *> *addedInstanceProperties;

/** The added class selectors. */
@property(nonatomic) NSSet<NSString *> *addedClassSelectors;

/** The added instance selectors. */
@property(nonatomic) NSSet<NSString *> *addedInstanceSelectors;

/** The modified imps. */
@property(nonatomic) NSSet<NSString *> *modifiedImps;

@end

NS_ASSUME_NONNULL_END
