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

#import <Foundation/Foundation.h>

/** This class generate the console URLs for a project or a metric*/
@interface FPRConsoleUrlGenerator : NSObject

/** This is a class method to generate the console URL for the project's dashboard page.*/
+ (NSString *)generateDashboardUrlWithProjectId:(NSString *)projectId bundleId:(NSString *)bundleId;

/** This is a class method to generate the console URL for the custom trace.*/
+ (NSString *)generateCustomTraceUrlWithProjectId:(NSString *)projectId
                                         bundleId:(NSString *)bundleId
                                        traceName:(NSString *)traceName;

/** This is a class method to generate the console URL for the screen trace.*/
+ (NSString *)generateScreenTraceUrlWithProjectId:(NSString *)projectId
                                         bundleId:(NSString *)bundleId
                                        traceName:(NSString *)traceName;

@end
