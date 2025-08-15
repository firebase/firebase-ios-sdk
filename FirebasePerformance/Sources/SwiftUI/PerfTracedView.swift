// Copyright 2025 Google LLC
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
#if canImport(SwiftUI)
  import FirebasePerformance
  import Foundation
  import SwiftUI

  // foregroud trace, screen render, refresh times
  // background trace, duration
  class PerfTraceViewModel {
    enum TraceType: String {
      case forground
      case background
    }

    let name: String
    var trace: Trace?
    var traceType: TraceType?

    var refreshCount: Int64 = 0

    lazy var displayLink: CADisplayLink = .init(target: self, selector: #selector(displayLinkStep))
    var previousTimestamp: CFTimeInterval = -1.0
    var slowFrameCount: Int64 = 0
    var totalFrameCount: Int64 = 0

    init(name: String) {
      self.name = name
    }

    func startScreenRenderMonitoring() {
      displayLink.add(to: .main, forMode: .common)
    }

    func stopScreenRenderMonitoring() {
      displayLink.remove(from: .main, forMode: .common)
    }

    // calling perf to start the trace
    func startTrace(_ traceType: TraceType) {
      if trace != nil {
        print("there is active trace already, can't start another one")
      }
      self.traceType = traceType
      trace = Performance().trace(name: "\(name)_\(traceType.rawValue)")
      print("trace start \(name)")
      trace?.start()
      if self.traceType == .forground {
        startScreenRenderMonitoring()
      }
    }

    // calling perf to end the trace
    func endTrace() {
      print("trace end")
      if traceType == .forground {
        stopScreenRenderMonitoring()
        trace?.setValue(totalFrameCount, forMetric: "totalFrameCount")
        trace?.setValue(slowFrameCount, forMetric: "slowFrameCount")
      }
      trace?.stop()
      trace = nil
      traceType = nil
      refreshCount = 0
    }

    func logChanges() {
      refreshCount = refreshCount + 1
      print("refresh count changed to: \(refreshCount)")
      trace?.setValue(refreshCount, forMetric: "refreshCount")
    }

    @objc
    func displayLinkStep() {
      let currentTimestamp = displayLink.timestamp
      if previousTimestamp > 0 {
        let frameDuration = currentTimestamp - previousTimestamp
        if frameDuration > 1.0 / 59.0 {
          slowFrameCount += 1
        }
      }
      totalFrameCount += 1
      previousTimestamp = currentTimestamp
    }
  }

  public struct PerfTracedView<Content: View>: View {
    @State private var viewModel: PerfTraceViewModel

    let content: () -> Content

    // Init through view builder
    public init(_ viewName: String, @ViewBuilder content: @escaping () -> Content) {
      self.content = content
      // print("Type of this content is: \(content()) ")
      viewModel = PerfTraceViewModel(name: viewName)
    }

    @Environment(\.scenePhase) var scenePhase

    public var body: some View {
      viewModel.logChanges()

      return content()
        .onAppear {
          print("\(viewModel.name) On appear \(Date().timeIntervalSince1970)")
          viewModel.startTrace(.forground)
        }
        .onDisappear {
          print("\(viewModel.name) On disaappear \(Date().timeIntervalSince1970)")
          viewModel.endTrace()
        }
        .onChange(of: scenePhase) { oldValue, newPhase in
          if newPhase == .active {
            print("\(viewModel.name) Active \(Date().timeIntervalSince1970)")
            if viewModel.traceType == .forground {
              print("foreground trace already running")
            } else {
              viewModel.endTrace()
              viewModel.startTrace(.forground)
            }
          } else if newPhase == .inactive {
            print("\(viewModel.name) Inactive \(Date().timeIntervalSince1970)")
            viewModel.endTrace()
            viewModel.startTrace(.background)
          } else if newPhase == .background {
            print("\(viewModel.name) Background \(Date().timeIntervalSince1970)")
          }
        }
    }
  }

  public extension View {
    func perfTrace(_ viewName: String) -> some View {
      return PerfTracedView(viewName) {
        self
      }
    }
  }
#endif
