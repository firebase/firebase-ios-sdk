/*
 * Copyright 2020 Google LLC
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

#import "FirebaseSegmentation/Sources/SEGSegmentationConstants.h"

NSString* const kFIRLoggerSegmentation = @"[Firebase/Segmentation]";

/// Keys for values stored in the Segmentation SDK.
NSString* const kSEGFirebaseApplicationIdentifierKey = @"firebase_app_identifier";
NSString* const kSEGCustomInstallationIdentifierKey = @"custom_installation_identifier";
NSString* const kSEGFirebaseInstallationIdentifierKey = @"firebase_installation_identifier";
NSString* const kSEGAssociationStatusKey = @"association_status";
/// Association Status
NSString* const kSEGAssociationStatusPending = @"PENDING";
NSString* const kSEGAssociationStatusAssociated = @"ASSOCIATED";

/// Segmentation error domain when logging errors.
NSString* const kFirebaseSegmentationErrorDomain = @"com.firebase.segmentation";

/// Used for reporting generic internal Segmentation errors.
NSString* const kSEGErrorDescription = @"SEGErrorDescription";

/// Segmentation Request Completion callback.
/// @param success Decide whether the network operation succeeds.
/// @param result  Return operation result data.
typedef void (^SEGRequestCompletion)(BOOL success, NSDictionary<NSString*, id>* result);
