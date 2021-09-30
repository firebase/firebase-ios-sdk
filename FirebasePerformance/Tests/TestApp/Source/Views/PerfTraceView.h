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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRTrace.h"

@class PerfTraceView;

@protocol PerfTraceViewDelegate <NSObject>

/**
 * Delegate method that is called whenever the trace is stopped.
 *
 * @param traceView Instance of the traceView generating the request to stop.
 */
- (void)perfTraceViewTraceStopped:(nonnull PerfTraceView *)traceView;

@end

/**
 * PerfTraceView represents an FPRTrace in the PerfSDK. This class will enable the user to create
 * a view, add stages, initialize/increment metrics and stop the trace. This object also
 * abstracts the use of the PerfSDK's FPRTrace object.
 */
@interface PerfTraceView : UIView

@property(nonatomic, nonnull, readonly) FIRTrace *trace;
@property(nonatomic, nullable, weak) id<PerfTraceViewDelegate> delegate;

/** @brief Not a valid initializer. */
- (nonnull instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;

/** @brief Not a valid initializer. */
- (nonnull instancetype)initWithCoder:(nullable NSCoder *)coder NS_UNAVAILABLE;

/** @brief Not a valid initializer. */
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
 * Creates a new trace view using the FPRTrace object provided.
 *
 * @param trace The trace object for which the view is created.
 * @param frame Frame size of the view.
 * @return An instance of PerfTraceView.
 */
- (nullable instancetype)initWithTrace:(nonnull FIRTrace *)trace
                                 frame:(CGRect)frame NS_DESIGNATED_INITIALIZER;

@end
