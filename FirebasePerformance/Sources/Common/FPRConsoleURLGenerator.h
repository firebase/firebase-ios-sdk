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

/** This class generated the console URLs for a project or a metric.*/
@interface FPRConsoleURLGenerator : NSObject

/**
 * Generates the console URL for the dashboard page of the project.
 *
 * @param projectID The Firebase project ID.
 * @param bundleID The bundle ID of this project.
 * @return The console URL for the dashboard page.
 */
+ (NSString *)generateDashboardURLWithProjectID:(NSString *)projectID bundleID:(NSString *)bundleID;

/**
 * Generates the console URL for the custom trace page.
 *
 * @param projectID The Firebase project ID.
 * @param bundleID The bundle ID of this project.
 * @return The console URL for the custom trace page.
 */
+ (NSString *)generateCustomTraceURLWithProjectID:(NSString *)projectID
                                         bundleID:(NSString *)bundleID
                                        traceName:(NSString *)traceName;

/**
 * Generates the console URL for the screen trace page.
 *
 * @param projectID The Firebase project ID.
 * @param bundleID The bundle ID of this project.
 * @return The console URL for the custom trace page.
 */
+ (NSString *)generateScreenTraceURLWithProjectID:(NSString *)projectID
                                         bundleID:(NSString *)bundleID
                                        traceName:(NSString *)traceName;

@end
