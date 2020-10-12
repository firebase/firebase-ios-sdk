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

NS_ASSUME_NONNULL_BEGIN

@class FIRApp;
/**
 * The Firebase Segmentation SDK is used to associate a custom, non-Firebase installation
 * identifier to Firebase. Once this custom installation identifier is set, developers can use the
 * current app installation for segmentation purposes. If the custom installation identifier is
 * explicitely set to nil, any existing custom installation identifier data will be removed.
 */
NS_SWIFT_NAME(Segmentation)
@interface FIRSegmentation : NSObject

/// Firebase Segmentation service fetch error.
typedef NS_ENUM(NSInteger, FIRSegmentationErrorCode) {
  /// No error. The operation was successful.
  FIRSegmentationErrorCodeNone = 8001,
  /// An internal error occurred.
  FIRSegmentationErrorCodeInternal = 8002,
  /// Error indicating that backend reports an existing association for this custom installation
  /// identifier.
  FIRSegmentationErrorCodeConflict = 8003,
  /// Error indicating that a network error occurred during association.
  FIRSegmentationErrorCodeNetwork = 8004,
} NS_SWIFT_NAME(SegmentationErrorCode);

/**
 * Singleton instance (scoped to the default FIRApp)
 * Returns the FIRSegmentation instance for the default Firebase application. Please make sure you
 * call [FIRApp configure] beforehand for a default Firebase app to already be initialized and
 * available. This singleton class instance lets you set your own custom identifier to be used for
 * user segmentation purposes within Firebase.
 *
 *  @return A shared instance of FIRSegmentation.
 */
+ (instancetype)segmentation;

/// Singleton instance (scoped to FIRApp)
/// Returns the FIRSegmentation instance for your Firebase application. This singleton class
/// instance lets you set your own custom identifier to be used for targeting purposes within
/// Firebase.
+ (instancetype)segmentationWithApp:(FIRApp *)app;

/**
 *  :nodoc:
 *  Unavailable. Use +segmentation instead.
 */
- (instancetype)init __attribute__((unavailable("Use +segmentation instead.")));

/// Set your own custom installation ID to be used for segmentation purposes.
/// This method needs to be called every time (and immediately) upon any changes to the custom
/// installation ID.
/// @param completionHandler Set custom installation ID completion. Returns nil if initialization
/// succeeded or an NSError object if initialization failed.
- (void)setCustomInstallationID:(nullable NSString *)customInstallationID
                     completion:(nullable void (^)(NSError *))completionHandler;

@end

NS_ASSUME_NONNULL_END
