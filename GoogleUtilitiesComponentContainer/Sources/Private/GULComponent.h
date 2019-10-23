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

@class GULComponentContainer;

NS_ASSUME_NONNULL_BEGIN

/// Provides a system to clean up cached instances returned from the component system.
NS_SWIFT_NAME(ComponentLifecycleMaintainer)
@protocol GULComponentLifecycleMaintainer
/// Clean up any resources as they are about to be deallocated.
- (void)containerWillBeEmptied:(GULComponentContainer *)container;
@end

typedef _Nullable id (^GULComponentCreationBlock)(GULComponentContainer *container,
                                                  BOOL *isCacheable)
    NS_SWIFT_NAME(ComponentCreationBlock);

@class GULDependency;

/// Describes the timing of instantiation. Note: new components should default to lazy unless there
/// is a strong reason to be eager.
typedef NS_ENUM(NSInteger, GULInstantiationTiming) {
  GULInstantiationTimingLazy,
  GULInstantiationTimingAlwaysEager
} NS_SWIFT_NAME(InstantiationTiming);

/// A component that can be used from other components.
NS_SWIFT_NAME(Component)
@interface GULComponent : NSObject

/// The protocol describing functionality provided from the Component.
@property(nonatomic, strong, readonly) Protocol *protocol;

/// The timing of instantiation.
@property(nonatomic, readonly) GULInstantiationTiming instantiationTiming;

/// An array of dependencies for the component.
@property(nonatomic, copy, readonly) NSArray<GULDependency *> *dependencies;

/// A block to instantiate an instance of the component with the appropriate dependencies.
@property(nonatomic, copy, readonly) GULComponentCreationBlock creationBlock;

// There's an issue with long NS_SWIFT_NAMES that causes compilation to fail, disable clang-format
// for the next two methods.
// clang-format off

/// Creates a component with no dependencies that will be lazily initialized.
+ (instancetype)componentWithProtocol:(Protocol *)protocol
                        creationBlock:(GULComponentCreationBlock)creationBlock
NS_SWIFT_NAME(init(_:creationBlock:));

/// Creates a component to be registered with the component container.
///
/// @param protocol - The protocol describing functionality provided by the component.
/// @param instantiationTiming - When the component should be initialized. Use .lazy unless there's
///                              a good reason to be instantiated earlier.
/// @param dependencies - Any dependencies the `implementingClass` has, optional or required.
/// @param creationBlock - A block to instantiate the component with a container, and if
/// @return A component that can be registered with the component container.
+ (instancetype)componentWithProtocol:(Protocol *)protocol
                  instantiationTiming:(GULInstantiationTiming)instantiationTiming
                         dependencies:(NSArray<GULDependency *> *)dependencies
                        creationBlock:(GULComponentCreationBlock)creationBlock
NS_SWIFT_NAME(init(_:instantiationTiming:dependencies:creationBlock:));

// clang-format on

/// Unavailable.
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
