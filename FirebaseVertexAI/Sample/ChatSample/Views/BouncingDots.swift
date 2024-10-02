// Copyright 2023 Google LLC
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

struct BouncingDots: View {
  @State
  private var dot1YOffset: CGFloat = 0.0

  @State
  private var dot2YOffset: CGFloat = 0.0

  @State
  private var dot3YOffset: CGFloat = 0.0

  let animation = Animation.easeInOut(duration: 0.8)
    .repeatForever(autoreverses: true)

  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(Color.white)
        .frame(width: 10, height: 10)
        .offset(y: dot1YOffset)
        .onAppear {
          withAnimation(self.animation.delay(0.0)) {
            self.dot1YOffset = -5
          }
        }
      Circle()
        .fill(Color.white)
        .frame(width: 10, height: 10)
        .offset(y: dot2YOffset)
        .onAppear {
          withAnimation(self.animation.delay(0.2)) {
            self.dot2YOffset = -5
          }
        }
      Circle()
        .fill(Color.white)
        .frame(width: 10, height: 10)
        .offset(y: dot3YOffset)
        .onAppear {
          withAnimation(self.animation.delay(0.4)) {
            self.dot3YOffset = -5
          }
        }
    }
    .onAppear {
      let baseOffset: CGFloat = -2

      self.dot1YOffset = baseOffset
      self.dot2YOffset = baseOffset
      self.dot3YOffset = baseOffset
    }
  }
}

struct BouncingDots_Previews: PreviewProvider {
  static var previews: some View {
    BouncingDots()
      .frame(width: 200, height: 50)
      .background(.blue)
      .roundedCorner(10, corners: [.allCorners])
  }
}
