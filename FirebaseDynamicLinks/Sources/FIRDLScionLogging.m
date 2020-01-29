/*
 * Copyright 2018 Google
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

#import "DynamicLinks/FIRDLScionLogging.h"

#import <FirebaseAnalyticsInterop/FIRInteropParameterNames.h>

static NSString *const kFIRDLLogEventFirstOpenCampaign = @"dynamic_link_first_open";
static NSString *const kFIRDLLogEventAppOpenCampaign = @"dynamic_link_app_open";

void FIRDLLogEventToScion(FIRDLLogEvent event,
                          NSString *_Nullable source,
                          NSString *_Nullable medium,
                          NSString *_Nullable campaign,
                          id<FIRAnalyticsInterop> _Nullable analytics) {
  NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

  if (source) {
    parameters[kFIRIParameterSource] = source;
  }
  if (medium) {
    parameters[kFIRIParameterMedium] = medium;
  }
  if (campaign) {
    parameters[kFIRIParameterCampaign] = campaign;
  }

  NSString *name;
  switch (event) {
    case FIRDLLogEventFirstOpen:
      name = kFIRDLLogEventFirstOpenCampaign;
      break;
    case FIRDLLogEventAppOpen:
      name = kFIRDLLogEventAppOpenCampaign;
      break;
  }

  if (name) {
    [analytics logEventWithOrigin:@"fdl" name:name parameters:parameters];
  }
}
