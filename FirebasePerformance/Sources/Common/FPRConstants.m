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

#import "FirebasePerformance/Sources/Common/FPRConstants.h"

// extract macro value into a C string
#define STR_FROM_MACRO(x) #x
#define STR(x) STR_FROM_MACRO(x)

// SDK Version number.
const char *const kFPRSDKVersion = (const char *const)STR(FIRPerformance_LIB_VERSION);

// Characters used prefix for internal naming of objects.
NSString *const kFPRInternalNamePrefix = @"_";

// Max length for object names
int const kFPRMaxNameLength = 100;

// Max URL length.
int const kFPRMaxURLLength = 2000;

// Max length for attribute name.
int const kFPRMaxAttributeNameLength = 40;

// Max length for attribute value.
int const kFPRMaxAttributeValueLength = 100;

// Maximum number of global custom attributes.
int const kFPRMaxGlobalCustomAttributesCount = 5;

// Maximum number of trace custom attributes.
int const kFPRMaxTraceCustomAttributesCount = 5;
