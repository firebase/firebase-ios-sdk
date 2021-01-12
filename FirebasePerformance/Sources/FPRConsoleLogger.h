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

#import "FirebaseCore/Sources/Private/FIRLogger.h"

NS_ASSUME_NONNULL_BEGIN

#define FPRLogDebug(messageCode, ...) FIRLogDebug(kFIRLoggerPerf, messageCode, __VA_ARGS__)
#define FPRLogError(messageCode, ...) FIRLogError(kFIRLoggerPerf, messageCode, __VA_ARGS__)
#define FPRLogInfo(messageCode, ...) FIRLogInfo(kFIRLoggerPerf, messageCode, __VA_ARGS__)
#define FPRLogNotice(messageCode, ...) FIRLogNotice(kFIRLoggerPerf, messageCode, __VA_ARGS__)
#define FPRLogWarning(messageCode, ...) FIRLogWarning(kFIRLoggerPerf, messageCode, __VA_ARGS__)

// FPR Client message codes.
FOUNDATION_EXTERN NSString* const kFPRClientInitialize;
FOUNDATION_EXTERN NSString* const kFPRClientTempDirectory;
FOUNDATION_EXTERN NSString* const kFPRClientCreateWorkingDirectory;
FOUNDATION_EXTERN NSString* const kFPRClientClearcutUpload;
FOUNDATION_EXTERN NSString* const kFPRClientInstanceIDNotAvailable;
FOUNDATION_EXTERN NSString* const kFPRClientNameTruncated;
FOUNDATION_EXTERN NSString* const kFPRClientNameReserved;
FOUNDATION_EXTERN NSString* const kFPRClientInvalidTrace;
FOUNDATION_EXTERN NSString* const kFPRClientMetricLogged;
FOUNDATION_EXTERN NSString* const kFPRClientDataUpload;
FOUNDATION_EXTERN NSString* const kFPRClientNameLengthCheckFailed;
FOUNDATION_EXTERN NSString* const kFPRClientPerfNotConfigured;
FOUNDATION_EXTERN NSString* const kFPRClientSDKDisabled;

// FPR Trace message codes.
FOUNDATION_EXTERN NSString* const kFPRTraceNoName;
FOUNDATION_EXTERN NSString* const kFPRTraceAlreadyStopped;
FOUNDATION_EXTERN NSString* const kFPRTraceNotStarted;
FOUNDATION_EXTERN NSString* const kFPRTraceDisabled;
FOUNDATION_EXTERN NSString* const kFPRTraceEmptyName;
FOUNDATION_EXTERN NSString* const kFPRTraceStartedNotStopped;
FOUNDATION_EXTERN NSString* const kFPRTraceNotCreated;
FOUNDATION_EXTERN NSString* const kFPRTraceInvalidName;

// FPR NetworkTrace message codes.
FOUNDATION_EXTERN NSString* const kFPRNetworkTraceFileError;
FOUNDATION_EXTERN NSString* const kFPRNetworkTraceInvalidInputs;
FOUNDATION_EXTERN NSString* const kFPRNetworkTraceURLLengthExceeds;
FOUNDATION_EXTERN NSString* const kFPRNetworkTraceURLLengthTruncation;
FOUNDATION_EXTERN NSString* const kFPRNetworkTraceNotTrackable;

// FPR LogSampler message codes.
FOUNDATION_EXTERN NSString* const kFPRSamplerInvalidConfigs;

// FPR attributes message codes.
FOUNDATION_EXTERN NSString* const kFPRAttributeNoName;
FOUNDATION_EXTERN NSString* const kFPRAttributeNoValue;
FOUNDATION_EXTERN NSString* const kFPRMaxAttributesReached;
FOUNDATION_EXTERN NSString* const kFPRAttributeNameIllegalCharacters;

// Manual network instrumentation codes.
FOUNDATION_EXTERN NSString* const kFPRInstrumentationInvalidInputs;
FOUNDATION_EXTERN NSString* const kFPRInstrumentationDisabledAfterConfigure;

// FPR diagnostic message codes.
FOUNDATION_EXTERN NSString* const kFPRDiagnosticInfo;
FOUNDATION_EXTERN NSString* const kFPRDiagnosticFailure;
FOUNDATION_EXTERN NSString* const kFPRDiagnosticLog;

// FPR Configuration related error codes.
FOUNDATION_EXTERN NSString* const kFPRConfigurationFetchFailure;

// FPR URL filtering message codes.
FOUNDATION_EXTERN NSString* const kFPRURLAllowlistingEnabled;

// FPR Gauge manager codes.
FOUNDATION_EXTERN NSString* const kFPRGaugeManagerDataCollected;
FOUNDATION_EXTERN NSString* const kFPRSessionId;
FOUNDATION_EXTERN NSString* const kFPRCPUCollection;
FOUNDATION_EXTERN NSString* const kFPRMemoryCollection;

// FPRSDKConfiguration message codes.
FOUNDATION_EXTERN NSString* const kFPRSDKFeaturesBlock;

NS_ASSUME_NONNULL_END
