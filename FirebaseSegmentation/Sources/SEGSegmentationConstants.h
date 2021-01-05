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

extern NSString* const kFIRLoggerSegmentation;

/// Keys for values stored in the Segmentation SDK.
extern NSString* const kSEGFirebaseApplicationIdentifierKey;
extern NSString* const kSEGCustomInstallationIdentifierKey;
extern NSString* const kSEGFirebaseInstallationIdentifierKey;
extern NSString* const kSEGAssociationStatusKey;
/// Association Status
extern NSString* const kSEGAssociationStatusPending;
extern NSString* const kSEGAssociationStatusAssociated;

/// Segmentation error domain when logging errors.
extern NSString* const kFirebaseSegmentationErrorDomain;

/// Used for reporting generic internal Segmentation errors.
extern NSString* const kSEGErrorDescription;

/// Segmentation Request Completion callback.
/// @param success Decide whether the network operation succeeds.
/// @param result  Return operation result data.
typedef void (^SEGRequestCompletion)(BOOL success, NSDictionary<NSString*, id>* result);
