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

#import "FirebaseCore/Sources/Private/FIRAppInternal.h"

NS_ASSUME_NONNULL_BEGIN

/** A fake FIRApp subclass, used for testing. */
@interface FIRAppFake : FIRApp

/** Is used to override isDataCollectionDefaultEnabled. */
@property(nonatomic) BOOL fakeIsDataCollectionDefaultEnabled;

+ (nullable FIRAppFake *)defaultApp;

/** Resets this class, releasing the current singleton returned by +defaultApp, allowing a new one
 *  to be allocated.
 */
+ (void)reset;

@end

NS_ASSUME_NONNULL_END
