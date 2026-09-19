---
name: style-and-commit
description: Ensure code is styled and commits follow Conventional Commits.
---

# Style & Commit Skill

When you are asked to commit changes, you MUST use the [Conventional
Commits](https://www.conventionalcommits.org/) specification.

## Format
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Pre-commit Workflow
Before staging and committing files, you MUST ensure that all repository
formatting and styling guidelines are met by running the unified pre-commit
script:
1. Locate and run the `pre_commit.sh` script. Depending on where this skill is
   installed, it will be at one of these paths:
   - `./.agents/skills/style_and_commit/scripts/pre_commit.sh` (Local Repo)
   - `~/.gemini/config/skills/style_and_commit/scripts/pre_commit.sh` (Global)
   Execute the path that exists. This script automatically:
   - Formats code (Swift, Obj-C, etc.)
   - Checks and adds copyright headers
   - Wraps markdown text at 80 characters and removes trailing whitespace
   - Runs `shellcheck` on any modified shell scripts
2. If the script fails (e.g., shellcheck reports an error), you MUST read the
   error, fix the issues, and re-run the script until it succeeds.
3. If the markdown formatter fails due to line length, you MUST wrap the lines.
   If wrapping is impossible without breaking correctness (e.g., long URLs or
   symbols), append ` <!-- ignore-wrap -->` to the end of the line.
4. Once the script passes, stage the intended changes (`git add ...`) and
   commit using `git commit -m "..."`.

## Rules
1. **Types**: Use one of the following types:
   - `feat`: A new feature
   - `fix`: A bug fix
   - `docs`: Documentation only changes
   - `style`: Changes that do not affect the meaning of the code (white-space,
     formatting, missing semi-colons, etc)
   - `refactor`: A code change that neither fixes a bug nor adds a feature
   - `perf`: A code change that improves performance
   - `test`: Adding missing tests or correcting existing tests
   - `build`: Changes that affect the build system or external dependencies
     (example scopes: gulp, broccoli, npm)
   - `ci`: Changes to our CI configuration files and scripts (example scopes:
     Travis, Circle, BrowserStack, GitHub Actions)
   - `chore`: Other changes that don't modify src or test files
   - `revert`: Reverts a previous commit
2. **Scope**: A scope may be provided to a commit's type, to provide additional
   contextual information and is contained within parenthesis, e.g.,
   `feat(parser): add ability to parse arrays`.
3. **Description**:
   - Use the imperative, present tense: "change" not "changed" nor "changes".
   - Don't capitalize the first letter.
   - No dot (.) at the end.
4. **Body**:
   - Just as in the description, use the imperative, present tense.
   - The body should include the motivation for the change and contrast this
     with previous behavior.
5. **Separate logical changes**: If the user's working directory has multiple
   unrelated changes (e.g. CI changes and Dependency updates), you should
   create separate commits for each logical change unless the user explicitly
   asks for a single commit.
6. **CI Fixes**: When making fixes to CI configuration files or workflows (e.g.
   GitHub Actions), use `fix` as the commit type and `ci` as the scope (e.g.
   `fix(ci): <description>`), rather than using `ci` as the type.
