// Copyright 2026 Google LLC
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

#if compiler(>=6.4)
  import Foundation
  import Testing

  @testable import FoundationModelsFake

  @Suite("OptionsTests")
  struct OptionsTests {
    @Test
    func generationOptionsDefaults() {
      let options = GenerationOptions()

      #expect(options.samplingMode == nil)
      #expect(options.temperature == nil)
      #expect(options.maximumResponseTokens == nil)
      #expect(options.toolCallingMode == nil)
    }

    @Test
    func generationOptionsCustom() {
      var options = GenerationOptions(
        samplingMode: .random(top: 3, seed: 1),
        temperature: 0.5,
        maximumResponseTokens: 10,
        toolCallingMode: .disallowed
      )

      #expect(options.samplingMode == .random(top: 3, seed: 1))
      #expect(options.temperature == 0.5)
      #expect(options.maximumResponseTokens == 10)
      #expect(options.toolCallingMode == .disallowed)

      options.samplingMode = .greedy
      #expect(options.samplingMode == .greedy)
    }

    @Test
    func samplingModeKindsAndEquality() {
      let greedy = GenerationOptions.SamplingMode.greedy
      let topK5 = GenerationOptions.SamplingMode.random(top: 5)
      let topK5Seed = GenerationOptions.SamplingMode.random(top: 5, seed: 9)
      let prob = GenerationOptions.SamplingMode.random(probabilityThreshold: 0.5)
      let probSeed = GenerationOptions.SamplingMode.random(probabilityThreshold: 0.5, seed: 9)

      #expect(greedy.kind == .greedy)
      #expect(topK5.kind == .randomTopK(5, seed: nil))
      #expect(topK5Seed.kind == .randomTopK(5, seed: 9))
      #expect(prob.kind == .randomProbabilityThreshold(0.5, seed: nil))
      #expect(probSeed.kind == .randomProbabilityThreshold(0.5, seed: 9))

      #expect(topK5 == GenerationOptions.SamplingMode.random(top: 5, seed: nil))
      #expect(
        GenerationOptions.SamplingMode.random(top: 5, seed: 1)
          != GenerationOptions.SamplingMode.random(top: 5, seed: 2))
      #expect(greedy != GenerationOptions.SamplingMode.random(top: 1))
    }

    @Test
    func toolCallingModeKindsAndEquality() {
      var mode = GenerationOptions.ToolCallingMode.allowed
      let required = GenerationOptions.ToolCallingMode.required
      let disallowed = GenerationOptions.ToolCallingMode.disallowed

      #expect(mode.kind == .allowed)
      #expect(required.kind == .required)
      #expect(disallowed.kind == .disallowed)

      #expect(mode != disallowed)
      #expect(mode != required)

      mode.kind = .disallowed
      #expect(mode == disallowed)
    }

    @Test
    func contextOptionsDefaultsAndCustom() {
      let defaultOptions = ContextOptions()
      let customOptions = ContextOptions(
        includeSchemaInPrompt: true,
        reasoningLevel: .custom("ultra")
      )

      #expect(defaultOptions.includeSchemaInPrompt == nil)
      #expect(defaultOptions.reasoningLevel == nil)
      #expect(customOptions.includeSchemaInPrompt == true)
      #expect(customOptions.reasoningLevel == .custom("ultra"))
    }

    @Test
    func reasoningLevelEqualityAndDescriptions() {
      let light = ContextOptions.ReasoningLevel.light
      let moderate = ContextOptions.ReasoningLevel.moderate
      let deep = ContextOptions.ReasoningLevel.deep
      let customA1 = ContextOptions.ReasoningLevel.custom("a")
      let customA2 = ContextOptions.ReasoningLevel.custom("a")
      let customB = ContextOptions.ReasoningLevel.custom("b")

      #expect(light != moderate)
      #expect(moderate != deep)
      #expect(customA1 == customA2)
      #expect(customA1 != customB)

      #expect(String(describing: light) == "light")
      #expect(String(describing: moderate) == "moderate")
      #expect(String(describing: deep) == "deep")
      #expect(String(describing: customA1) == "custom(\"a\")")
    }

    @Test
    func optionsEqualityEdgeCases() {
      #expect(GenerationOptions() == GenerationOptions())
      #expect(
        GenerationOptions(samplingMode: .greedy) == GenerationOptions(samplingMode: .greedy)
      )
      #expect(
        GenerationOptions(temperature: 0.5) == GenerationOptions(temperature: 0.5)
      )
      #expect(
        GenerationOptions(temperature: nil) != GenerationOptions(temperature: 0.0)
      )
      #expect(
        GenerationOptions(toolCallingMode: nil)
          != GenerationOptions(toolCallingMode: .allowed)
      )
      #expect(ContextOptions() == ContextOptions())
      #expect(
        ContextOptions() != ContextOptions(includeSchemaInPrompt: true)
      )
    }
  }
#endif  // compiler(>=6.4)
