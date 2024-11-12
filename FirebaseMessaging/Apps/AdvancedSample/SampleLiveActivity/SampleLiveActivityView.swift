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

import SwiftUI
import WidgetKit

struct SampleLiveActivityView: View {
  let context: ActivityViewContext<SampleLiveActivityAttributes>

  var body: some View {
    VStack {
      HStack {
        Image(systemName: "cup.and.saucer")
        ProgressView(value: context.state.status.rawValue, total: 2)
          .tint(.black)
          .background(Color.brown)
        Image(systemName: "cup.and.saucer.fill")
      }
      .padding(16)

      Text("\(context.state.status.description)")
        .font(.system(size: 18, weight: .semibold))
        .padding(.bottom)
      Text("Instance No: " + String(context.attributes.lvInstanceNumber))
        .font(.system(size: 18, weight: .semibold))
        .padding(.bottom)
      Spacer()
    }
    .background(Color.brown.opacity(0.6))
  }
}
