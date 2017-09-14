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

#include <unordered_map>

#pragma mark - Hashing functions

/** Hashes Class and SEL pointers as values, which is similar to how they're handled by the default
 *  equal_to<T> template; C++ doesn't know anything about ObjC types.
 */
struct FIRClassSelectorHasher {
  size_t operator()(const std::pair<Class, SEL> &obj) const {
    return *(size_t *)(void *)(&obj.first) ^ *(size_t *)(void *)(&obj.second);
  }
};

#pragma mark - Convenience typedefs

// A convenience typedef to abstract the Class/SEL -> IMP unordered map.
typedef std::unordered_map<std::pair<Class, SEL>, IMP, FIRClassSelectorHasher> FIRSwizzleMap;

// A convenience typedef to abstract an IMP -> IMP unordered map.
typedef std::unordered_map<IMP, IMP> FIRNewIMPToOriginalIMPMap;

#pragma mark - Shared swizzling caches

/** Creates and returns the shared queue on which swizzling occurs. */
extern dispatch_queue_t GetFIRSwizzlingQueue();

/** Ensures the singleton map of Class/SEL -> IMP is instantiated and returns it.
 *  @return The shared swizzle map.
 */
extern FIRSwizzleMap *FIRPreviousImpCache();

/** Ensures the singleton map of new IMP -> original IMP is instantiated and returns it.
 *  @return The singleton IMP to IMP map.
 */
extern FIRNewIMPToOriginalIMPMap *FIRNewToOriginalImp();
