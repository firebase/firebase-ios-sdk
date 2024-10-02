// Copyright 2024 Google LLC
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

#if SWIFT_PACKAGE
@import FirebaseCrashlyticsSwift;
#elif __has_include(<FirebaseCrashlytics/FirebaseCrashlytics-Swift.h>)
#import <FirebaseCrashlytics/FirebaseCrashlytics-Swift.h>
#elif __has_include("FirebaseCrashlytics-Swift.h")
// If frameworks are not available, fall back to importing the header as it
// should be findable from a header search path pointing to the build
// directory. See #12611 for more context.
#import "FirebaseCrashlytics-Swift.h"
#endif

@interface FIRCLSRolloutsPersistenceManager : NSObject <FIRCLSPersistenceLog>

- (instancetype _Nullable)initWithFileManager:(FIRCLSFileManager *_Nonnull)fileManager
                                     andQueue:(dispatch_queue_t _Nonnull)queue;
- (instancetype _Nonnull)init NS_UNAVAILABLE;
+ (instancetype _Nonnull)new NS_UNAVAILABLE;

- (void)updateRolloutsStateToPersistenceWithRollouts:(NSData *_Nonnull)rollouts
                                            reportID:(NSString *_Nonnull)reportID;
- (void)debugLogWithMessage:(NSString *_Nonnull)message;
@end
