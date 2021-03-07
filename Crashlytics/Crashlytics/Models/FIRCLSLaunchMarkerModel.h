// Copyright 2021 Google LLC
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

#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * Writes a file during startup, and deletes it at the end. Existence
 * of this file on the next run means there was a crash at launch,
 * because the file wasn't deleted. This is used to make Crashlytics
 * block startup on uploading the crash.
 */
@interface FIRCLSLaunchMarkerModel : NSObject

- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (BOOL)checkForAndCreateLaunchMarker;
- (BOOL)createLaunchFailureMarker;
- (BOOL)removeLaunchFailureMarker;

@end

NS_ASSUME_NONNULL_END
