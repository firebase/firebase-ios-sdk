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

// SDK Version number.
FOUNDATION_EXTERN const char* const kFPRSDKVersion;

// Prefix for internal naming of objects
FOUNDATION_EXTERN NSString* const kFPRInternalNamePrefix;

// Max length for object names
FOUNDATION_EXTERN int const kFPRMaxNameLength;

// Max URL length
FOUNDATION_EXTERN int const kFPRMaxURLLength;

// Max length for attribute name.
FOUNDATION_EXTERN int const kFPRMaxAttributeNameLength;

// Max length for attribute value.
FOUNDATION_EXTERN int const kFPRMaxAttributeValueLength;

// Maximum number of global custom attributes.
FOUNDATION_EXTERN int const kFPRMaxGlobalCustomAttributesCount;

// Maximum number of trace custom attributes.
FOUNDATION_EXTERN int const kFPRMaxTraceCustomAttributesCount;
