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

#import <Foundation/Foundation.h>

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORAssert.h"

NS_ASSUME_NONNULL_BEGIN

/** Allows the setting a block to be used in the GDTCORAssert macro instead of assertion log. */
@interface GDTCORAssertHelper : NSObject

/** A class property that can be run instead of normal assertion logging. */
@property(class, nullable, nonatomic) GDTCORAssertionBlock assertionBlock;

@end

NS_ASSUME_NONNULL_END
