
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

NS_ASSUME_NONNULL_BEGIN

/**
 * The release information returned by the update check when a new version is available.
 */
NS_SWIFT_NAME(AppDistributionRelease)
@interface FIRAppDistributionRelease : NSObject

/// The short bundle version of this build (example 1.0.0).
@property(nonatomic, copy, readonly) NSString *displayVersion;

/// The build number of this build (example: 123).
@property(nonatomic, copy, readonly) NSString *buildVersion;

/// The release notes for this build.
@property(nonatomic, copy, readonly) NSString *releaseNotes;

/// The URL for the build.
@property(nonatomic, strong, readonly) NSURL *downloadURL;

/// Whether the download URL for this release is expired.
@property(nonatomic, readonly) BOOL isExpired;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
