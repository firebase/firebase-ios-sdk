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

#import <GoogleDataTransport/GoogleDataTransport.h>

/**
 * FPRGDTRateLimiter class helps in limiting the number of events that are sent
 * to the backend. This is based on the token bucket rate limiting algorithm.
 */
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
@interface FPRGDTRateLimiter : NSObject <GDTCOREventTransformer>

@end
