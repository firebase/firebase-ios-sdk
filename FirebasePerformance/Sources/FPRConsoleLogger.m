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

#import "FirebasePerformance/Sources/FPRConsoleLogger.h"

// FPR Client message codes.
NSString* const kFPRClientInitialize = @"I-PRF100001";
NSString* const kFPRClientTempDirectory = @"I-PRF100002";
NSString* const kFPRClientCreateWorkingDirectory = @"I-PRF100003";
NSString* const kFPRClientClearcutUpload = @"I-PRF100004";
NSString* const kFPRClientInstanceIDNotAvailable = @"I-PRF100005";
NSString* const kFPRClientNameTruncated = @"I-PRF100006";
NSString* const kFPRClientNameReserved = @"I-PRF100007";
NSString* const kFPRClientInvalidTrace = @"I-PRF100008";
NSString* const kFPRClientMetricLogged = @"I-PRF100009";
NSString* const kFPRClientDataUpload = @"I-PRF100010";
NSString* const kFPRClientNameLengthCheckFailed = @"I-PRF100012";
NSString* const kFPRClientPerfNotConfigured = @"I-PRF100013";
NSString* const kFPRClientSDKDisabled = @"I-PRF100014";

// FPR Trace message codes.
NSString* const kFPRTraceNoName = @"I-PRF200001";
NSString* const kFPRTraceAlreadyStopped = @"I-PRF200002";
NSString* const kFPRTraceNotStarted = @"I-PRF200003";
NSString* const kFPRTraceDisabled = @"I-PRF200004";
NSString* const kFPRTraceEmptyName = @"I-PRF200005";
NSString* const kFPRTraceStartedNotStopped = @"I-PRF200006";
NSString* const kFPRTraceNotCreated = @"I-PRF200007";
NSString* const kFPRTraceInvalidName = @"I-PRF200008";

// FPR NetworkTrace message codes.
NSString* const kFPRNetworkTraceFileError = @"I-PRF300001";
NSString* const kFPRNetworkTraceInvalidInputs = @"I-PRF300002";
NSString* const kFPRNetworkTraceURLLengthExceeds = @"I-PRF300003";
NSString* const kFPRNetworkTraceNotTrackable = @"I-PRF300004";
NSString* const kFPRNetworkTraceURLLengthTruncation = @"I-PRF300005";

// FPR LogSampler message codes.
NSString* const kFPRSamplerInvalidConfigs = @"I-PRF400001";

// FPR Attributes message codes.
NSString* const kFPRAttributeNoName = @"I-PRF500001";
NSString* const kFPRAttributeNoValue = @"I-PRF500002";
NSString* const kFPRMaxAttributesReached = @"I-PRF500003";
NSString* const kFPRAttributeNameIllegalCharacters = @"I-PRF500004";

// Manual network instrumentation codes.
NSString* const kFPRInstrumentationInvalidInputs = @"I-PRF600001";
NSString* const kFPRInstrumentationDisabledAfterConfigure = @"I-PRF600002";

// FPR diagnostic message codes.
NSString* const kFPRDiagnosticInfo = @"I-PRF700001";
NSString* const kFPRDiagnosticFailure = @"I-PRF700002";
NSString* const kFPRDiagnosticLog = @"I-PRF700003";

// FPR Configuration related error codes.
NSString* const kFPRConfigurationFetchFailure = @"I-PRF710001";

// FPR URL filtering message codes.
NSString* const kFPRURLAllowlistingEnabled = @"I-PRF800001";

// FPR Gauge manager codes.
NSString* const kFPRGaugeManagerDataCollected = @"I-PRF900001";
NSString* const kFPRSessionId = @"I-PRF900002";
NSString* const kFPRCPUCollection = @"I-PRF900003";
NSString* const kFPRMemoryCollection = @"I-PRF900004";

// FPRSDKConfiguration message codes.
NSString* const kFPRSDKFeaturesBlock = @"I-PRF910001";
