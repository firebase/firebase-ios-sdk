# gfm: Gemini Foundation Models CLI

`gfm` is a command-line utility modeled after Apple's built-in `fm` (Foundation
Models) CLI. It provides an interface to generate content, run interactive chat
sessions, validate model availability, and construct structured schemas using
Google Gemini (`GeminiLanguageModel`) and Apple System models
(`SystemLanguageModel`).

## Requirements

*   macOS 26.0 or later (macOS 27.0+ recommended for `SystemLanguageModel`), or
    iOS 27.0+ (Simulator or device)
*   Swift 6.0 or later / Xcode 26.2+
*   A Gemini API key (obtainable from Google AI Studio) for `gemini` models

## Authentication and Model Selection

`gfm` defaults to using the `gemini` model family (`gemini-3.5-flash-lite`).

### Setting your API key

Authenticate with the Gemini Developer API by exporting an environment variable
in your shell:

```bash
export GOOGLE_API_KEY="your-gemini-api-key"
# or
export GEMINI_API_KEY="your-gemini-api-key"
```

> [!NOTE]
> If both environment variables are set, `GOOGLE_API_KEY` takes precedence over
> `GEMINI_API_KEY`.

Alternatively, pass your key explicitly using the `--api-key` flag:

```bash
gfm respond --api-key "your-gemini-api-key" "Explain quantum computing briefly."
```

### Model selection options

* `-m, --model <gemini|system>`: Select the backend model (`gemini` by default).
* `--gemini-model <model-id>`: Specify a Gemini model variant (defaults to
  `gemini-3.5-flash-lite`, e.g. `gemini-2.5-pro` or `gemini-2.5-flash`).
* `--api-variant, --api <generate-content|interactions>`: Specify the Gemini API
  variant (`generate-content` by default, or `interactions`).

## Building and Running

### 1. Run directly with `swift run`

You can run `gfm` without installing it using `swift run`.

#### From the repository root:

```bash
# General help
swift run --package-path GeminiLanguageModel/Samples/gfm gfm --help

# Check model availability
swift run --package-path GeminiLanguageModel/Samples/gfm gfm available

# Generate a response
swift run --package-path GeminiLanguageModel/Samples/gfm gfm respond "Explain Swift concurrency."

# Start an interactive chat session
swift run --package-path GeminiLanguageModel/Samples/gfm gfm chat
```

#### From the sample directory:

```bash
cd GeminiLanguageModel/Samples/gfm

# Run commands directly
swift run gfm available
swift run gfm respond "Write a haiku about Xcode."
swift run gfm chat
```

### 2. Build and run the compiled binary

For repeated executions without SwiftPM dependency resolution overhead, compile
a release executable:

```bash
# From the repository root
swift build --package-path GeminiLanguageModel/Samples/gfm -c release

# Run the compiled binary
./GeminiLanguageModel/Samples/gfm/.build/release/gfm --version
./GeminiLanguageModel/Samples/gfm/.build/release/gfm available
```

#### Optional: Create an alias or link to your `$PATH`

```bash
# Shell alias
alias gfm="$(pwd)/GeminiLanguageModel/Samples/gfm/.build/release/gfm"

# Or symlink into local binaries
ln -sf "$(pwd)/GeminiLanguageModel/Samples/gfm/.build/release/gfm" /usr/local/bin/gfm
```

### 3. Run on iOS Simulator via Xcode

If your Mac is running macOS 26 and does not yet have macOS 27 for on-device
`SystemLanguageModel` support, you can build and run `gfm` targeting an **iOS 27
Simulator** inside Xcode:

1.  **Open the package in Xcode**:
    ```bash
    open GeminiLanguageModel/Samples/gfm/Package.swift
    ```
2.  **Select the Scheme and Destination**:
    *   Select the `gfm` executable scheme in the Xcode toolbar.
    *   Choose an **iOS 27 Simulator** destination (e.g. `iPhone 17 Pro`).
3.  **Configure Arguments and Environment Variables**:
    *   Go to **Product > Scheme > Edit Scheme...** (`⌘<`).
    *   Select **Run** in the left sidebar, then choose the **Arguments** tab.
    *   **Arguments Passed On Launch**: Add the command arguments you want to run,
        for example:
        *   `available`
        *   `respond "Write a haiku about Swift."`
        *   `respond --api interactions "Explain how quantum computers work."`
        *   `chat`
    *   **Environment Variables**: Click `+` and add:
        *   Name: `GOOGLE_API_KEY` (or `GEMINI_API_KEY`)
        *   Value: `<your-gemini-api-key>`
    *   *(Optional)* Under the **Options** tab, set **Console** to **Use standard
        console** if you are running an interactive `chat` session.
4.  **Run**:
    *   Press `⌘R` (or click the Run button).
    *   The output streams directly in Xcode's debug console pane (`⇧⌘Y`).

You can also build or test directly from the command line for iOS Simulator:

```bash
# Build for iOS Simulator
xcodebuild -scheme gfm -destination 'generic/platform=iOS Simulator'

# Run unit tests on an iOS 27 Simulator
xcodebuild test -scheme gfm -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Commands and Usage

### 1. `available`

Check the availability of configured language models on your system.

```bash
# Check all models
gfm available

# Check Gemini model availability
gfm available -m gemini

# Check Apple System Language Model availability
gfm available -m system
```

### 2. `respond`

Generate a response for a single prompt or piped input with real-time streaming.

```bash
# Direct argument prompt
gfm respond "Write a haiku about Swift concurrency."

# Read prompt from piped stdin
cat document.txt | gfm respond

# Pipe text and ask a question about it
cat article.txt | gfm respond "What are the main takeaways?"
git diff | gfm respond "Summarize these git changes as a commit message."

# System instructions
gfm respond -i "You are an expert iOS engineer." "How does @Observable work?"

# Use Apple's on-device System model
gfm respond -m system "Why is the sky blue?"

# Save response transcript to a session
gfm respond --save-transcript "my-session" "Remember that my favorite color is blue."

# Resume an existing session
gfm respond --resume "my-session" "What is my favorite color?"

# Call built-in demo tools
gfm respond --tool current-time "What time is it right now?"

# Use the Interactions API instead of Generate Content
gfm respond --api interactions "Explain how quantum computers work."
```

#### Structured Output with `--schema`

You can enforce structured JSON outputs by pairing `--schema` with property
definitions:

```bash
gfm respond \
  --schema 'name:string age:integer role:string' \
  "Generate a fictional software engineer profile."
```

### 3. `chat`

Start an interactive, multi-turn chat session with streaming responses.

```bash
# Start an interactive chat using the default Gemini model
gfm chat

# Start a chat with the on-device System model
gfm chat -m system

# Start a chat with system instructions
gfm chat -i "You are a helpful coding assistant."

# Enable tool calling in chat
gfm chat --tool current-time

# Resume a previous session
gfm chat -r "my-session"

# Continue the most recent session
gfm chat -c

# Start a chat session using the Interactions API
gfm chat --api interactions
```

#### In-Chat Slash Commands

While in a chat session, type any of the following commands:

*   `/help` - Display available chat commands.
*   `/clear` - Clear the current conversation transcript.
*   `/sessions` - List saved sessions stored in `~/.fm/sessions/`.
*   `/exit` - Save transcript and quit the session.

### 4. `schema object`

Generate and preview standard JSON schema definitions:

```bash
# Primitive types
gfm schema object --name Person --string name --integer age --boolean is_active

# Optional and array modifiers
gfm schema object --name Dog --string breed --description "Breed of dog" --boolean friendly --optional --string tags --array

# Nested object properties using dot notation
gfm schema object --name Restaurant --string name --string address.street --string address.zip
```

## Running Tests

Run the test suite from the repository root:

```bash
swift test --package-path GeminiLanguageModel/Samples/gfm
```

Or from the sample directory:

```bash
cd GeminiLanguageModel/Samples/gfm
swift test
```

All unit tests run deterministically without requiring an active network
connection or valid API credentials.
