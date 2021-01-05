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

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

// This file contains declarations that should go into FirebaseCore when
// Firebase InAppMessaging is merged into master. Keep them separate now to help
// with build from development folder and avoid merge conflicts.

// this should eventually be in FIRLogger.h
extern FIRLoggerService kFIRLoggerInAppMessaging;

// this should eventually be in FIRError.h
extern NSString *const kFirebaseInAppMessagingErrorDomain;

// InAppMessaging doesn't provide any functionality to other components,
// so it provides a private, empty protocol that it conforms to and use it for registration.

@protocol FIRInAppMessagingInstanceProvider
@end
