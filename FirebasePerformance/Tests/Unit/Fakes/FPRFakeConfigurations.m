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

#import "FirebasePerformance/Tests/Unit/Fakes/FPRFakeConfigurations.h"

@interface FPRFakeConfigurations ()

@property(nonatomic) BOOL collectionEnabled;
@property(nonatomic) BOOL autoInstrumentationEnabled;
@property(nonatomic) int perfLogSource;
@property(nonatomic) BOOL perfSdkEnabled;
@property(nonatomic) BOOL perfDiagnosticsEnabled;

@property(nonatomic) float normalTraceSamplingRate;
@property(nonatomic) float networkTraceSamplingRate;

@property(nonatomic) uint32_t foregroundEventCount;
@property(nonatomic) uint32_t foregroundTimelimit;
@property(nonatomic) uint32_t backgroundEventCount;
@property(nonatomic) uint32_t backgroundTimelimit;
@property(nonatomic) uint32_t foregroundNetworkEventCount;
@property(nonatomic) uint32_t foregroundNetworkTimelimit;
@property(nonatomic) uint32_t backgroundNetworkEventCount;
@property(nonatomic) uint32_t backgroundNetworkTimelimit;

@property(nonatomic) float sessionSamplingRate;
@property(nonatomic) uint32_t maxSessionLength;
@property(nonatomic) uint32_t cpuSamplingFrequencyInForeground;
@property(nonatomic) uint32_t cpuSamplingFrequencyInBackground;
@property(nonatomic) uint32_t memorySamplingFrequencyInForeground;
@property(nonatomic) uint32_t memorySamplingFrequencyInBackground;

@end

@implementation FPRFakeConfigurations

- (BOOL)isDataCollectionEnabled {
  return self.collectionEnabled;
}

- (BOOL)isInstrumentationEnabled {
  return self.autoInstrumentationEnabled;
}

- (int)logSource {
  return self.perfLogSource;
}

- (BOOL)sdkEnabled {
  return self.perfSdkEnabled;
}

- (BOOL)diagnosticsEnabled {
  return self.perfDiagnosticsEnabled;
}

- (float)logTraceSamplingRate {
  return self.normalTraceSamplingRate;
}

- (float)logNetworkSamplingRate {
  return self.networkTraceSamplingRate;
}

- (uint32_t)foregroundEventCount {
  return _foregroundEventCount;
}

- (uint32_t)foregroundEventTimeLimit {
  return self.foregroundTimelimit;
}

- (uint32_t)backgroundEventCount {
  return _backgroundEventCount;
}

- (uint32_t)backgroundEventTimeLimit {
  return self.backgroundTimelimit;
}

- (uint32_t)foregroundNetworkEventCount {
  return _foregroundNetworkEventCount;
}

- (uint32_t)foregroundNetworkEventTimeLimit {
  return self.foregroundNetworkTimelimit;
}

- (uint32_t)backgroundNetworkEventCount {
  return _backgroundNetworkEventCount;
}

- (uint32_t)backgroundNetworkEventTimeLimit {
  return self.backgroundNetworkTimelimit;
}

- (float_t)sessionsSamplingPercentage {
  return self.sessionSamplingRate;
}

- (uint32_t)maxSessionLengthInMinutes {
  return self.maxSessionLength;
}

- (uint32_t)cpuSamplingFrequencyInForegroundInMS {
  return self.cpuSamplingFrequencyInForeground;
}

- (uint32_t)cpuSamplingFrequencyInBackgroundInMS {
  return self.cpuSamplingFrequencyInBackground;
}

- (uint32_t)memorySamplingFrequencyInForegroundInMS {
  return self.memorySamplingFrequencyInForeground;
}

- (uint32_t)memorySamplingFrequencyInBackgroundInMS {
  return self.memorySamplingFrequencyInBackground;
}

#pragma mark - Configurations setters

- (void)setDataCollectionEnabled:(BOOL)dataCollectionEnabled {
  self.collectionEnabled = dataCollectionEnabled;
}

- (void)setInstrumentationEnabled:(BOOL)instrumentationEnabled {
  self.autoInstrumentationEnabled = instrumentationEnabled;
}

- (void)setLogSource:(int)logSource {
  self.perfLogSource = logSource;
}

- (void)setSdkEnabled:(BOOL)enabled {
  self.perfSdkEnabled = enabled;
}

- (void)setDiagnosticsEnabled:(BOOL)enabled {
  self.perfDiagnosticsEnabled = enabled;
}

#pragma mark - Sampling related configurations.

- (void)setTraceSamplingRate:(float)rate {
  self.normalTraceSamplingRate = rate;
}

- (void)setNetworkSamplingRate:(float)rate {
  self.networkTraceSamplingRate = rate;
}

#pragma mark - Rate limiting related configurations.

- (void)setForegroundTimeLimit:(uint32_t)timeLimit {
  self.foregroundTimelimit = timeLimit;
}

- (void)setBackgroundTimeLimit:(uint32_t)timeLimit {
  self.backgroundTimelimit = timeLimit;
}

- (void)setForegroundNetworkTimeLimit:(uint32_t)timeLimit {
  self.foregroundNetworkTimelimit = timeLimit;
}

- (void)setBackgroundNetworkTimeLimit:(uint32_t)timeLimit {
  self.backgroundNetworkTimelimit = timeLimit;
}

#pragma mark - Session related configurations.

- (void)setSessionsSamplingPercentage:(float)rate {
  self.sessionSamplingRate = rate;
}

- (void)setMaxSessionLengthInMinutes:(uint32_t)minutes {
  self.maxSessionLength = minutes;
}

- (void)setCpuSamplingFrequencyInForegroundInMS:(uint32_t)frequency {
  self.cpuSamplingFrequencyInForeground = frequency;
}

- (void)setCpuSamplingFrequencyInBackgroundInMS:(uint32_t)frequency {
  self.cpuSamplingFrequencyInBackground = frequency;
}

- (void)setMemorySamplingFrequencyInForegroundInMS:(uint32_t)frequency {
  self.memorySamplingFrequencyInForeground = frequency;
}

- (void)setMemorySamplingFrequencyInBackgroundInMS:(uint32_t)frequency {
  self.memorySamplingFrequencyInBackground = frequency;
}

@end
