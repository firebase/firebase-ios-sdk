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

#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument.h"

#import "FirebasePerformance/Sources/Instrumentation/FPRObjectInstrumentor.h"

NS_ASSUME_NONNULL_BEGIN

/** This class instruments the delegate methods needed to start/stop trace correctly. This class is
 *  not intended to be used standalone--it should only be used by FPRNSURLConnectionInstrument.
 */
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
@interface FPRNSURLConnectionDelegateInstrument : FPRInstrument <FPRObjectInstrumentorProtocol>

/** Registers an instrument for a delegate class if it hasn't yet been instrumented.
 *
 *  @note This method is thread-safe.
 *  @param aClass The class to instrument.
 */
- (void)registerClass:(Class)aClass;

@end

NS_ASSUME_NONNULL_END
