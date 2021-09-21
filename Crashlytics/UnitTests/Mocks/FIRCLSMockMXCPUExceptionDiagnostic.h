// Copyright 2021 Google LLC
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

#include <Availability.h>
#import <Foundation/Foundation.h>

#import "Crashlytics/Crashlytics/Helpers/FIRCLSDefines.h"

#if CLS_METRICKIT_SUPPORTED
#import <MetricKit/MetricKit.h>
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXCallStackTree.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXMetadata.h"

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(14))
@interface FIRCLSMockMXCPUExceptionDiagnostic : MXCPUExceptionDiagnostic

- (instancetype)initWithCallStackTree:(FIRCLSMockMXCallStackTree *)callStackTree
                         totalCPUTime:(NSMeasurement<NSUnitDuration *> *)totalCPUTime
                     totalSampledTime:(NSMeasurement<NSUnitDuration *> *)totalSampledTime
                             metaData:(FIRCLSMockMXMetadata *)metaData
                   applicationVersion:(NSString *)applicationVersion;

@property(readonly, strong, nonnull) FIRCLSMockMXCallStackTree *callStackTree;

@property(readonly, strong, nonnull) NSMeasurement<NSUnitDuration *> *totalCPUTime;

@property(readonly, strong, nonnull) NSMeasurement<NSUnitDuration *> *totalSampledTime;

@property(readonly, strong, nonnull) FIRCLSMockMXMetadata *metaData;

@property(readonly, strong, nonnull) NSString *applicationVersion;

@end

NS_ASSUME_NONNULL_END

#endif
