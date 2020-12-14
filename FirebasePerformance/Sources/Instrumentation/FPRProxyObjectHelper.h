// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

/** This class helps the instrumentation deal with objects that have been wrapped with NSProxy
 *  objects after being swizzled by other SDKs. In particular, Crittercism swizzles NSURLSessions
 *  and makes every NSURLSession initialization method return an NSProxy subclass.
 */
@interface FPRProxyObjectHelper : NSObject

/** Registers a proxy object for a given class and runs the onSuccess block whenever an ivar of the
 *  given class is discovered on the proxy object.
 *
 *  @param proxy The proxy object whose ivars will be iterated.
 *  @param superclass The superclass all ivars will be compared against. See varFoundHandler.
 *  @param varFoundHandler The block to run when an ivar isKindOfClass:aClass.
 */
+ (void)registerProxyObject:(id)proxy
              forSuperclass:(Class)superclass
            varFoundHandler:(void (^)(id ivar))varFoundHandler;

@end
