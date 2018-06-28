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

#ifndef FIRComponentRegistrant_h
#define FIRComponentRegistrant_h

#import <Foundation/Foundation.h>

@class FIRComponent;

NS_ASSUME_NONNULL_BEGIN

/// Describes functionality for SDKs registering components in the `FIRComponentContainer`.
NS_SWIFT_NAME(ComponentRegistrant)
@protocol FIRComponentRegistrant

/// Returns one or more FIRComponents that will be registered in
/// FIRApp and participate in dependency resolution and injection.
+ (NSArray<FIRComponent *> *)componentsToRegister;

@end

NS_ASSUME_NONNULL_END

#endif /* FIRComponentRegistrant_h */
