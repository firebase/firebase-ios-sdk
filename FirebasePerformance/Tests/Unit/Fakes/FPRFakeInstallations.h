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

#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

NS_ASSUME_NONNULL_BEGIN

/** An object which simulates behavior of Firebase Installations. */
@interface FPRFakeInstallations : NSObject

/** Installations ID which is used to identify a Firebase app installation. */
@property(nonatomic, nullable) NSString *identifier;

/*
 * A method which creates a FPRFakeInstallations object.
 */
+ (instancetype)installations;

/*
 * A fake method which assumes an installation ID is retrieved successfully,
 * and will call completion handler immediately.
 */
- (void)installationIDWithCompletion:(FIRInstallationsIDHandler)completion;

@end

NS_ASSUME_NONNULL_END
