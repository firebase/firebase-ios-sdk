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

#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"

/**
 * Extension that is added on top of the class FPRDiagnostics to make the private properties
 * visible between the implementation file and the unit tests.
 */
@interface FPRDiagnostics ()

/** FPRCongiguration to check if diagnostic is enabled. */
@property(class, nonatomic, readwrite) FPRConfigurations *configuration;

@end
