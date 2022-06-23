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

#import "FirebasePerformance/Sources/Common/FPRConsoleURLGenerator.h"

NSString *const URL_BASE_PATH = @"https://console.firebase.google.com";
NSString *const UTM_MEDIUM = @"ios-ide";
NSString *const UTM_SOURCE = @"perf-ios-sdk";

@implementation FPRConsoleURLGenerator

/** This is a class method to generate the console URL for the project's dashboard page.*/
+ (NSString *)generateDashboardURLWithProjectID:(NSString *)projectID
                                       bundleID:(NSString *)bundleID {
  NSString *rootUrl = [FPRConsoleURLGenerator getRootURLWithProjectID:projectID bundleID:bundleID];
  return [NSString
      stringWithFormat:@"%@/trends?utm_source=%@&utm_medium=%@", rootUrl, UTM_SOURCE, UTM_MEDIUM];
}

/** This is a class method to generate the console URL for the custom trace.*/
+ (NSString *)generateCustomTraceURLWithProjectID:(NSString *)projectID
                                         bundleID:(NSString *)bundleID
                                        traceName:(NSString *)traceName {
  NSString *rootUrl = [FPRConsoleURLGenerator getRootURLWithProjectID:projectID bundleID:bundleID];
  return [NSString stringWithFormat:@"%@/troubleshooting/trace/"
                                    @"DURATION_TRACE/%@?utm_source=%@&utm_medium=%@",
                                    rootUrl, traceName, UTM_SOURCE, UTM_MEDIUM];
}

/** This is a class method to generate the console URL for the screen trace.*/
+ (NSString *)generateScreenTraceURLWithProjectID:(NSString *)projectID
                                         bundleID:(NSString *)bundleID
                                        traceName:(NSString *)traceName {
  NSString *rootUrl = [FPRConsoleURLGenerator getRootURLWithProjectID:projectID bundleID:bundleID];
  return [NSString stringWithFormat:@"%@/troubleshooting/trace/"
                                    @"SCREEN_TRACE/%@?utm_source=%@&utm_medium=%@",
                                    rootUrl, traceName, UTM_SOURCE, UTM_MEDIUM];
}

/** This is a class method to get the root URL for the console .*/
+ (NSString *)getRootURLWithProjectID:(NSString *)projectID bundleID:(NSString *)bundleID {
  return [NSString
      stringWithFormat:@"%@/project/%@/performance/app/ios:%@", URL_BASE_PATH, projectID, bundleID];
}
@end
