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

/** This class handles the caching and retreival of IMPs as we swizzle and unswizzle them. It uses
 *  two C++ STL unordered_maps as the underlying data store. This class is NOT thread safe.
 */
@interface GULSwizzlingCache : NSObject

/** Singleton initializer.
 *
 *  @return a singleton GULSwizzlingCache.
 */
+ (instancetype)sharedInstance;

/** Save the existing IMP that exists before we install the new IMP for a class, selector combo.
 *  If the currentIMP is something that we put there, it will ignore it and instead point newIMP
 *  to what existed before we swizzled.
 *
 *  @param newIMP new The IMP that is going to replace the current IMP.
 *  @param currentIMP The IMP returned by class_getMethodImplementation.
 *  @param aClass The class that we're swizzling.
 *  @param selector The selector we're swizzling.
 */
- (void)cacheCurrentIMP:(IMP)currentIMP
              forNewIMP:(IMP)newIMP
               forClass:(Class)aClass
           withSelector:(SEL)selector;

/** Returns the cached IMP that would be invoked with the class and selector combo had we
 *  never swizzled.
 *
 *  @param aClass The class the selector would be invoked on.
 *  @param selector The selector
 *  @return The original IMP i.e. the one that existed right before GULSwizzler swizzled either
 *  this or a superclass.
 */
- (IMP)cachedIMPForClass:(Class)aClass withSelector:(SEL)selector;

/** Clears the cache of values we no longer need because we've unswizzled the relevant method.
 *
 *  @param swizzledIMP The IMP we replaced the existing IMP with.
 *  @param selector The selector which that we swizzled for.
 *  @param aClass The class that we're swizzling.
 */
- (void)clearCacheForSwizzledIMP:(IMP)swizzledIMP selector:(SEL)selector aClass:(Class)aClass;

@end
