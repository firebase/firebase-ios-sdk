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

#import "Firestore/Source/Local/FSTGarbageCollector.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A garbage collector implementation that eagerly collects documents as soon as they're no longer
 * referenced in any of its registered FSTGarbageSources.
 *
 * This implementation keeps track of a set of keys that are potentially garbage without keeping
 * an exact reference count. During -collectGarbage, the collector verifies that all potential
 * garbage keys actually have no references by consulting its list of garbage sources.
 */
@interface FSTEagerGarbageCollector : NSObject <FSTGarbageCollector>
@end

NS_ASSUME_NONNULL_END
