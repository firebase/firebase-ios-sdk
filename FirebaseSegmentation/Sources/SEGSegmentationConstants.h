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

#ifndef SEGSegmentationConstants_h
#define SEGSegmentationConstants_h

#if defined(DEBUG)
#define SEG_MUST_NOT_BE_MAIN_THREAD()                                                 \
  do {                                                                                \
    NSAssert(![NSThread isMainThread], @"Must not be executing on the main thread."); \
  } while (0);
#else
#define SEG_MUST_NOT_BE_MAIN_THREAD() \
  do {                                \
  } while (0);
#endif

static NSString* const kFIRLoggerSegmentation = @"[Firebase/Segmentation]";

/// Keys for values stored in the Segmentation SDK.
static NSString* const kSEGFirebaseApplicationIdentifierKey = @"firebase_app_identifier";
static NSString* const kSEGCustomInstallationIdentifierKey = @"custom_installation_identifier";
static NSString* const kSEGFirebaseInstallationIdentifierKey = @"firebase_installation_identifier";
static NSString* const kSEGAssociationStatusKey = @"association_status";
/// Association Status
static NSString* const kSEGAssociationStatusPending = @"PENDING";
static NSString* const kSEGAssociationStatusAssociated = @"ASSOCIATED";

/// Segmentation error domain when logging errors.
extern NSString* const kFirebaseSegmentationErrorDomain;

/// Segmentation Request Completion callback.
/// @param success Decide whether the network operation succeeds.
/// @param result  Return operation result data.
typedef void (^SEGRequestCompletion)(BOOL success, NSDictionary<NSString*, id>* result);

#endif /* SEGSegmentationConstants_h */
