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

import Testing
import SharedDataModels
import GoogleAIDataModels
import AgentPlatformDataModels
@testable import GeminiAPIClient

@Suite struct GeminiDataModelMappingTests {
  @Test func testContentMapping() throws {
    // 1. Unified to Backend
    let unifiedContent = GeminiContent(
      role: "user",
      parts: [
        GeminiPart(text: "Hello world"),
        GeminiPart(inlineData: Blob(data: "base64bytes", mimeType: "image/png"))
      ]
    )

    let googleAIContent = unifiedContent.toGoogleAI()
    #expect(googleAIContent.role == "user")
    #expect(googleAIContent.parts?.count == 2)
    #expect(googleAIContent.parts?[0].text == "Hello world")
    #expect(googleAIContent.parts?[1].inlineData?.data == "base64bytes")
    #expect(googleAIContent.parts?[1].inlineData?.mimeType == "image/png")

    let agentPlatformContent = unifiedContent.toAgentPlatform()
    #expect(agentPlatformContent.role == "user")
    #expect(agentPlatformContent.parts?.count == 2)
    #expect(agentPlatformContent.parts?[0].text == "Hello world")
    #expect(agentPlatformContent.parts?[1].inlineData?.data == "base64bytes")
    #expect(agentPlatformContent.parts?[1].inlineData?.mimeType == "image/png")

    // 2. Backend to Unified
    let mappedFromGoogleAI = GeminiContent(fromGoogleAI: googleAIContent)
    #expect(mappedFromGoogleAI.role == "user")
    #expect(mappedFromGoogleAI.parts?[0].text == "Hello world")
    #expect(mappedFromGoogleAI.parts?[1].inlineData?.data == "base64bytes")

    let mappedFromAgentPlatform = GeminiContent(fromAgentPlatform: agentPlatformContent)
    #expect(mappedFromAgentPlatform.role == "user")
    #expect(mappedFromAgentPlatform.parts?[0].text == "Hello world")
    #expect(mappedFromAgentPlatform.parts?[1].inlineData?.data == "base64bytes")
  }

  @Test func testGenerationConfigMapping() throws {
    let unifiedConfig = GenerationConfig(
      candidateCount: 2,
      maxOutputTokens: 100,
      temperature: 0.7,
      topP: 0.9,
      audioTimestamp: true
    )

    // GoogleAI mapping (ignores audioTimestamp)
    let googleAIConfig = unifiedConfig.toGoogleAI()
    #expect(googleAIConfig.candidateCount == 2)
    #expect(googleAIConfig.maxOutputTokens == 100)
    #expect(googleAIConfig.temperature == 0.7)
    #expect(googleAIConfig.topP == 0.9)

    // AgentPlatform mapping (retains audioTimestamp)
    let agentPlatformConfig = unifiedConfig.toAgentPlatform()
    #expect(agentPlatformConfig.candidateCount == 2)
    #expect(agentPlatformConfig.maxOutputTokens == 100)
    #expect(agentPlatformConfig.temperature == 0.7)
    #expect(agentPlatformConfig.topP == 0.9)
    #expect(agentPlatformConfig.audioTimestamp == true)

    // Inverse mappings
    let fromGoogle = GenerationConfig(fromGoogleAI: googleAIConfig)
    #expect(fromGoogle.candidateCount == 2)
    #expect(fromGoogle.audioTimestamp == nil)

    let fromAP = GenerationConfig(fromAgentPlatform: agentPlatformConfig)
    #expect(fromAP.candidateCount == 2)
    #expect(fromAP.audioTimestamp == true)
  }

  @Test func testSafetySettingMapping() throws {
    let unifiedSetting = SafetySetting(
      category: .hateSpeech,
      threshold: .blockLowAndAbove,
      method: .severity
    )

    let googleAISetting = unifiedSetting.toGoogleAI()
    #expect(googleAISetting.category == .hateSpeech)
    #expect(googleAISetting.threshold == .blockLowAndAbove)

    let agentPlatformSetting = unifiedSetting.toAgentPlatform()
    #expect(agentPlatformSetting.category == .hateSpeech)
    #expect(agentPlatformSetting.threshold == .blockLowAndAbove)
    #expect(agentPlatformSetting.method == .severity)

    let fromGoogle = SafetySetting(fromGoogleAI: googleAISetting)
    #expect(fromGoogle.category == .hateSpeech)
    #expect(fromGoogle.method == nil)

    let fromAP = SafetySetting(fromAgentPlatform: agentPlatformSetting)
    #expect(fromAP.category == .hateSpeech)
    #expect(fromAP.method == .severity)
  }

  @Test func testToolMapping() throws {
    let unifiedTool = GeminiTool(
      codeExecution: CodeExecutionTool(),
      googleSearch: GoogleSearchTool()
    )

    let googleAITool = unifiedTool.toGoogleAI()
    #expect(googleAITool.codeExecution != nil)
    #expect(googleAITool.googleSearch != nil)

    let agentPlatformTool = unifiedTool.toAgentPlatform()
    #expect(agentPlatformTool.codeExecution != nil)
    #expect(agentPlatformTool.googleSearch != nil)
  }

  @Test func testGenerateContentRequestMapping() throws {
    let unifiedRequest = GenerateContentRequest(
      model: "gemini-1.5-pro",
      contents: [
        GeminiContent(role: "user", parts: [GeminiPart(text: "Hello")])
      ],
      toolConfig: ToolConfig(
        functionCallingConfig: FunctionCallingConfig(
          allowedFunctionNames: ["my_func"],
          mode: .any
        )
      ),
      serviceTier: .standard
    )

    let googleAIReq = unifiedRequest.toGoogleAI()
    #expect(googleAIReq.model == "gemini-1.5-pro")
    #expect(googleAIReq.serviceTier == .standard)
    #expect(googleAIReq.toolConfig?.functionCallingConfig?.allowedFunctionNames == ["my_func"])
    #expect(googleAIReq.toolConfig?.functionCallingConfig?.mode == .any)

    let agentPlatformReq = unifiedRequest.toAgentPlatform()
    #expect(agentPlatformReq.toolConfig?.functionCallingConfig?.allowedFunctionNames == ["my_func"])
    #expect(agentPlatformReq.toolConfig?.functionCallingConfig?.mode == .any)

    let fromGoogle = GenerateContentRequest(fromGoogleAI: googleAIReq)
    #expect(fromGoogle.model == "gemini-1.5-pro")
    #expect(fromGoogle.serviceTier == .standard)
    #expect(fromGoogle.toolConfig?.functionCallingConfig?.allowedFunctionNames == ["my_func"])

    let fromAP = GenerateContentRequest(fromAgentPlatform: agentPlatformReq)
    #expect(fromAP.toolConfig?.functionCallingConfig?.allowedFunctionNames == ["my_func"])
  }
}
