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
import FirebaseMessaging
import SampleLiveActivityExtension
import SwiftUI

struct LiveActivityView: View {
  @State var activityTokenDict = [String: String]()

  var body: some View {
    VStack {
      Button("Refresh List") {
        Task {
          refreshAcitivtyList()
        }
      }.padding(10)

      Button("Cancel all running Activities") {
        cancelAllRunningActivities()
      }.padding(10)

      Button("Start Live Activity with push") {
        startLiveActivity(supportPush: true)
      }.padding(10)

      Button("Start Live Activity without push") {
        startLiveActivity(supportPush: false)
      }.padding(10)

      List {
        ForEach(activityTokenDict.keys.sorted(), id: \.self) { key in
          VStack {
            Text("ActivityId: " + key).frame(maxWidth: .infinity, alignment: .leading)

            Button("Copy") {
              UIPasteboard.general.string = activityTokenDict[key]!
            }.frame(alignment: .trailing)

            Text("Push Token: " + activityTokenDict[key]!)
              .frame(maxWidth: .infinity, alignment: .leading)
          }.padding(10)
        }
      }
    }.onAppear {
      refreshAcitivtyList()
    }
  }

  private func refreshAcitivtyList() {
    Task {
      activityTokenDict.removeAll()

      let ptsToken = Activity<SampleLiveActivityAttributes>.pushToStartToken

      if ptsToken != nil {
        let ptsTokenString = getFormattedToken(token: ptsToken!)
        activityTokenDict["PTS"] = ptsTokenString
      } else {
        activityTokenDict["PTS"] = "Not available yet.!"
        Task {
          for await ptsToken in Activity<SampleLiveActivityAttributes>
            .pushToStartTokenUpdates {
            let ptsTokenString = getFormattedToken(token: ptsToken)
            activityTokenDict["PTS"] = ptsTokenString
            refreshAcitivtyList()
          }
        }
      }

      let activities = Activity<SampleLiveActivityAttributes>.activities
      for activity in activities {
        if activity.pushToken != nil {
          let activityToken = getFormattedToken(token: activity.pushToken!)
          activityTokenDict[activity.id] = activityToken
        } else {
          activityTokenDict[activity.id] = "Not available yet!"
        }
      }
    }
  }

  func getFormattedToken(token: Data) -> String {
    return token.reduce("") {
      $0 + String(format: "%02x", $1)
    }
  }

  private func startLiveActivity(supportPush: Bool) {
    let lAttributes = SampleLiveActivityAttributes(lvInstanceNumber: Date()
      .timeIntervalSince1970)
    let initialState = SampleLiveActivityAttributes.ContentState(status: .started)
    let content = ActivityContent(state: initialState, staleDate: nil, relevanceScore: 1.0)

    if supportPush {
      let activity = try? Activity.request(
        attributes: lAttributes,
        content: content,
        pushType: .token
      )

      if activity != nil {
        Task {
          for await pushToken in activity!.pushTokenUpdates {
            let activityToken = getFormattedToken(token: pushToken)
            activityTokenDict[activity!.id] = activityToken
            refreshAcitivtyList()
          }
        }
      }
    } else {
      let activity = try? Activity.request(
        attributes: lAttributes,
        content: content,
        pushType: .none
      )
    }

    refreshAcitivtyList()
  }

  func cancelAllRunningActivities() {
    Task {
      for activity in Activity<SampleLiveActivityAttributes>.activities {
        let initialContentState = SampleLiveActivityAttributes
          .ContentState(status: .started)

        await activity.end(
          ActivityContent(state: initialContentState, staleDate: Date()),
          dismissalPolicy: .immediate
        )
      }

      refreshAcitivtyList()
    }
  }
}

#Preview {
  LiveActivityView()
}
