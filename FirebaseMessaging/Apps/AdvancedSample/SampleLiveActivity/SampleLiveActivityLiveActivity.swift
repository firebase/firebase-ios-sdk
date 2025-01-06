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

import ActivityKit
import SwiftUI
import WidgetKit

struct SampleLiveActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    enum LVStatus: Float, Codable, Hashable {
      case started = 0
      case inProgress = 1
      case completed = 2

      var description: String {
        switch self {
        case .started:
          return "Your Live Activity is started!"
        case .inProgress:
          return "Your Live Activity is in progress!"
        case .completed:
          return "Your Live activity is completed!"
        }
      }
    }

    let status: LVStatus
  }

  // Fixed non-changing properties about your activity go here!
  var lvInstanceNumber: Double
}

struct SampleLiveActivityLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: SampleLiveActivityAttributes.self) { context in
      // Lock screen/banner UI goes here
      VStack {
        SampleLiveActivityView(context: context)
      }
      .activityBackgroundTint(Color.cyan)
      .activitySystemActionForegroundColor(Color.black)

    } dynamicIsland: { context in
      DynamicIsland {
        // Expanded UI goes here.  Compose the expanded UI through
        // various regions, like leading/trailing/center/bottom
        DynamicIslandExpandedRegion(.leading) {
          Text("Leading")
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text("Trailing")
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text("Bottom")
          // more content
        }
      } compactLeading: {
        Text("L")
      } compactTrailing: {
        Text("T")
      } minimal: {
        Text("M")
      }
      .widgetURL(URL(string: "http://www.apple.com"))
      .keylineTint(Color.red)
    }
  }
}

private extension SampleLiveActivityAttributes {
  static var preview: SampleLiveActivityAttributes {
    SampleLiveActivityAttributes(lvInstanceNumber: 1)
  }
}

private extension SampleLiveActivityAttributes.ContentState {
  static var stateStarted: SampleLiveActivityAttributes.ContentState {
    SampleLiveActivityAttributes.ContentState(status: LVStatus.started)
  }

  static var stateInProgress: SampleLiveActivityAttributes.ContentState {
    SampleLiveActivityAttributes.ContentState(status: LVStatus.inProgress)
  }

  static var stateCompleted: SampleLiveActivityAttributes.ContentState {
    SampleLiveActivityAttributes.ContentState(status: LVStatus.completed)
  }
}

#Preview("Notification", as: .content, using: SampleLiveActivityAttributes.preview) {
  SampleLiveActivityLiveActivity()
} contentStates: {
  SampleLiveActivityAttributes.ContentState.stateStarted
  SampleLiveActivityAttributes.ContentState.stateInProgress
  SampleLiveActivityAttributes.ContentState.stateCompleted
}
