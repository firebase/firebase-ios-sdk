/*
 * Copyright 2017 Google
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

#ifndef Firebase_FIRDataEventType_h
#define Firebase_FIRDataEventType_h

#import <Foundation/Foundation.h>

/**
 * This enum is the set of events that you can observe at a Firebase Database location.
 */
typedef NS_ENUM(NSInteger, FIRDataEventType) {
    /// A new child node is added to a location.
    FIRDataEventTypeChildAdded,
    /// A child node is removed from a location.
    FIRDataEventTypeChildRemoved,
    /// A child node at a location changes.
    FIRDataEventTypeChildChanged,
    /// A child node moves relative to the other child nodes at a location.
    FIRDataEventTypeChildMoved,
    /// Any data changes at a location or, recursively, at any child node.
    FIRDataEventTypeValue
} NS_SWIFT_NAME(DataEventType);

#endif
