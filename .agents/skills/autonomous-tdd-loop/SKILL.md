---
name: autonomous-tdd-loop
description: Orchestrates a strict TDD loop across subagents to build features.
---

# Autonomous TDD Loop

This skill orchestrates a multi-agent workflow to implement code changes while
strictly enforcing test validation and code quality standards.

## Requirements
*   An `agents.md` file at the root of the repository must be present to define
    the Verifier and Reviewer personas for the current repository.

## The Workflow

When this skill is invoked, follow these exact phases in order:

### Phase 1: Applicability & Test Creation (Worker)
1.  **Assess:** Determine if a unit/regression test is applicable for the
    user's goal. Also assess the **validation scope** (e.g., does this need a
    full `xcodebuild` suite, or just a quick `./scripts/check_whitespace.sh`?).
    If a test is not applicable, state the reason, record your validation
    scope, and skip to Phase 4.
2.  **Write Test:** Write a failing test for the issue. *Do not apply the fix
    yet.*
    *   **Crucial Rule for Swift Concurrency / AsyncStream / URLSession
        Cancellation:** When writing tests to verify that an `AsyncStream`
        properly cleans up resources or cancels underlying network requests on
        termination, **do not mock delays that naturally finish the task.**
        Buffering in `URLSession` will mask timeouts, and naturally finishing a
        mocked operation will trigger system cleanup that masks missing explicit
        cancellation.
    *   **Instead:** Wrap the stream consumption in a consumer `Task`, yield or
        `Task.sleep` for a tiny duration (e.g. 100ms) to allow initialization,
        and explicitly call `.cancel()` on the consumer `Task`. Verify that the
        underlying mocked resource receives the cancellation (e.g.,
        `stopLoading()` is called).

### Phase 2: Sanity Check 1 (Verifier)
1.  Invoke a **Verifier** subagent using `invoke_subagent` (Role: "Objective
    Code Verifier").
2.  **Instruction to Verifier:** "Read the Root `AGENTS.md` for this repo to
    find the test execution command. Run the tests. Your ONLY goal is to verify
    that the specific test I just added currently **FAILS**. Do not try to fix
    it. Return a binary pass/fail result based on this."
3.  Wait for the Verifier's response. If the test does not fail, revise the
    test until it does.

### Phase 3: Implementation (Worker)
1.  Apply the code fix for the issue.

### Phase 4: Sanity Check 2 (Verifier)
1.  Send a message to the existing **Verifier** subagent.
2.  **Instruction to Verifier:** "I have applied a fix. Please run the
    tests/checks using the command from `AGENTS.md`, but optimize for the
    **validation scope** I determined in Phase 1 (e.g., if it's just a
    whitespace fix, only run the style script instead of the full test suite).
    Verify that the required checks now **PASS**."
3.  If the Verifier reports failures, iterate on the implementation and repeat
    this phase.

### Phase 5: Strict TDD Revert Loop (Worker & Verifier)
*Skip this phase if no tests were added in Phase 1.*
1.  Temporarily comment out or revert the core logic of the fix.
2.  Send a message to the **Verifier**: "I have temporarily reverted the fix.
    Run the tests again and confirm that the *exact same tests* fail again."
3.  Once the Verifier confirms the failure, uncomment/re-apply the fix.

### Phase 6: Qualitative Review (Reviewer)
1.  Invoke a **Reviewer** subagent using `invoke_subagent` (Role: "Rigorous
    Code Reviewer").
2.  **Instruction to Reviewer:** "Read the Root `AGENTS.md` and any
    `REVIEW_GUIDELINES.md` for this repo. Perform a rigorous, subjective code
    review on my changes. Focus on concurrency, memory management, and API
    design. Flag any issues."
3.  Iterate with the Reviewer until it approves the changes based on the rubric.

### Phase 7: Key Learnings & Completion
1.  **Systemic Memory:** If you encountered any systemic friction (e.g., a
    flaky simulator, a recurring build quirk, misleading existing
    documentation), append it to the `.agents/MEMORY.md` file in the workspace
    root.
2.  **Knowledge Migration:** If the friction you just recorded is a permanent
    quirk of the repository that all contributors should know about (rather
    than a transient local machine issue), explicitly prompt the user: "I added
    a note about [Topic] to your local `.agents/MEMORY.md`. I recommend we
    permanently add this to the repository's `AGENTS.md` file so all
    contributors benefit from this knowledge. Would you like me to do that?"
3.  If the user requested PR creation, use the `gh` CLI to create a PR and wait
    for CI/human feedback. Otherwise, notify the user that the loop is
    complete.
