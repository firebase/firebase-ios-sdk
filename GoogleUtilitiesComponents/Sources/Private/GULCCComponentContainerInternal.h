/*
 * Copyright 2019 Google
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

#import "GULCCComponent.h"
#import "GULCCComponentContainer.h"

NS_ASSUME_NONNULL_BEGIN

@interface GULCCComponentContainer (Private)

/// Initializes a container with a context.
- (instancetype)initWithContext:(nullable id)context;

/// Initializes a container with a context and a given set of registered `GULLibraries`.
- (instancetype)initWithContext:(nullable id)context
                    registrants:(NSMutableSet<Class> *)allRegistrants;

/// Retrieves an instance that conforms to the specified protocol. This will return `nil` if the
/// protocol wasn't registered, or if the instance couldn't be instantiated for the provided app.
- (nullable id)instanceForProtocol:(Protocol *)protocol NS_SWIFT_NAME(instance(for:));

/// Instantiates all the components that have registered as "eager" after initialization.
- (void)instantiateEagerComponents;

/// Remove all of the cached instances stored and allow them to clean up after themselves.
- (void)removeAllCachedInstances;

/// Register a class to provide components for the interoperability system. The class should conform
/// to `GULCCComponentRegistrant` and provide an array of `GULCCComponent` objects.
+ (void)registerAsComponentRegistrant:(Class<GULCCLibrary>)klass;

@end

NS_ASSUME_NONNULL_END
