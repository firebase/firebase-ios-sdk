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

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRComponentContainer (Testing)

/// Publicize this internal interface for testing: initializes a container with specific classes
/// registered as registrants.
- (instancetype)initWithApp:(FIRApp *)app registrants:(NSMutableSet<Class> *)allRegistrants;

/// Initializes an instance of a FIRComponentContainer for testing purposes. This does not set the
/// container property on the `app` argument.
- (instancetype)initWithApp:(FIRApp *)app
                 components:(NSDictionary<NSString *, FIRComponentCreationBlock> *)components;

@end

NS_ASSUME_NONNULL_END
