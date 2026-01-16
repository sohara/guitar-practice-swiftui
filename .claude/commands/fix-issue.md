---
allowed-tools: Bash(gh issue list:*), Bash(gh issue view:*)
description: Find and fix the first open GitHub issue
---

# Fix GitHub Issue Workflow

You are going to work through an issue from this project's GitHub repository.

## Current Open Issues
!gh issue list --state open --limit 5

## Your Task

1. **Identify the issue**: Look at the first (oldest) open issue from the list above. If arguments were provided (`$ARGUMENTS`), use that issue number instead.

2. **Enter plan mode**: Use the EnterPlanMode tool to enter plan mode and:
   - Explore the codebase to understand the issue
   - Create a detailed implementation plan
   - Ask clarifying questions if needed
   - Exit plan mode when the plan is ready for approval

3. **Implement the fix**: After the user approves your plan, implement the changes.

4. **Build and test**: Run `make run` to build and launch the app for testing.

5. **Wait for user confirmation**: Ask the user to test the fix. Do NOT proceed until they confirm it works.

6. **Update documentation**: After user confirms the fix works:
   - Update `docs/DEVLOG.md` with a new entry describing the fix (follow the existing format)
   - Optionally update `README.md`, `CLAUDE.md`, or other docs if the fix changes behavior that's documented there (use judgment - keep docs accurate and up to date, but don't make them more verbose)

7. **Commit and push**:
   - Stage all changes
   - Commit with a message that includes `fixes #<issue-number>` to auto-close the issue
   - Push to origin

8. **Verify**: Confirm the issue was closed automatically.

Remember: NEVER commit or push until the user has manually tested and confirmed the fix works.
