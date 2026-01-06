---
name: task-planner
description: Guide for planning tasks. Use this when asked plan a task.
---

# Task Planning Skill

## Purpose
Create actionable migration and implementation plans as structured markdown files in a `~/.agentic/plans/` directory. Plans should be clear, specific, and ready for implementation without requiring repeated clarification of expectations.

## Behavior Setup

### Plan Structure
Plans must follow this format:

```markdown
# [Task Title]

## Context
- Brief explanation of what changed and why
- Key technical decisions that led to this work
- 2-4 bullet points maximum

## [Domain Area] Changes Required

### [Subsystem Number]. [Subsystem Name]
**File**: `path/to/file.ts`

#### Actions:
- [ ] Specific action item with line numbers when relevant
  - [ ] Sub-action if the action has multiple steps
  - [ ] Another sub-action
- [ ] Another specific action item

**Note**: Additional context or clarification for this subsystem

### [Next Subsystem]...

## Summary of Breaking Changes
1. Clear statement of what breaks
2. What behavior changes
3. What must be updated

## Migration Order
1. First step - why it's first
2. Second step - dependencies
3. Third step - verification

## Key Pattern for [Core Concept]
\`\`\`typescript
// OLD PATTERN (DEPRECATED):
old approach

// NEW PATTERN (REQUIRED):
new approach with clear steps
\`\`\`
```

### Key Principles

#### 1. Plans Are Actions, Not Discussions
- ❌ "We should consider updating the API layer"
- ✅ "Update `ApiService.get()` to include version parameter (line 45)"
- ❌ "Think about how to handle errors"
- ✅ "Add error handling for 404 responses in `fetchData()` method"

#### 2. Specific Over Generic
- Include file paths for every subsystem
- Include line numbers when referencing existing code
- Include method/function names, not vague descriptions
- Show concrete code patterns in the "Key Pattern" section

#### 3. Question-Driven Clarification
When encountering unknowns:
- Ask specific, technical questions
- Offer concrete options (Option A, B, C)
- Wait for answers before finalizing the plan
- Update the plan with "RESOLVED ✅" markers after clarification

Format questions like:
```markdown
**Question for clarification**: How should we handle X scenario?
Options:
1. **Option A**: Approach 1 with trade-offs
2. **Option B**: Approach 2 with trade-offs
```

After resolution, replace with:
```markdown
#### [Topic] - RESOLVED ✅
- Clear statement of the decision
- Why this approach was chosen
- Implementation details
```

#### 4. Acknowledge Existing Patterns
- Reference existing services/helpers that solve the problem
- Note architectural patterns already in use
- Warn about anti-patterns (e.g., circular dependencies)
- Use what's there before inventing new solutions

Example:
```markdown
**Important**: Use the existing `FlatHierarchiesService` to avoid 
circular dependencies between stores. This service was designed 
specifically for this purpose.
```

#### 5. Order Matters
Migration order should:
- Update interfaces before implementations
- Update test/fake services immediately after interfaces
- Update stores/services that depend on interfaces
- Update components/UI last
- End with testing/verification

## Analysis Phase

### Before Writing the Plan
1. **Read the code being changed** - Don't guess at structure
2. **Find all dependents** - Use grep/search to find what calls the changed code
3. **Identify circular dependencies** - Note services that depend on each other
4. **Check for existing helpers** - Look for utilities that solve the problem
5. **Ask clarifying questions** - Don't assume; validate understanding

### Questions to Ask
- How does the backend behave now? (Read API contracts)
- What calls this code? (Search for usage)
- Are there timing/async concerns? (Check for race conditions)
- How do we get required data? (Trace data flow)
- What's the testing strategy? (Check test files)

## Plan Output

### File Location
- Always create plans in `~/.agentic/plans/` directory
- Create the directory if it doesn't exist (including parent directories)
- Use kebab-case for filenames: `feature-name-migration.md`

### File Naming
- `[feature]-migration.md` - For migrations/refactors
- `[feature]-implementation.md` - For new features
- `[bug-name]-fix.md` - For complex bug fixes

### Checkboxes
- Use `- [ ]` for all action items
- Nest sub-actions with proper indentation
- Mark resolved questions with `✅` emoji, not checkboxes

### Code Examples
- Always include "before/after" patterns
- Use the actual project's language/framework
- Show complete, working examples, not pseudocode
- Comment deprecated patterns clearly

## Collaboration Loop

### Initial Plan
1. Analyze the code and dependencies
2. Ask clarifying questions about unknowns
3. Present options for technical decisions
4. Wait for feedback

### Plan Refinement
1. Listen for corrections about:
   - How the backend actually works
   - Existing services/patterns to use
   - Architectural constraints
   - Default behaviors
2. Update the plan immediately with new information
3. Mark resolved items clearly
4. Resubmit for final approval

### Final Deliverable
- A complete, actionable plan
- No open questions
- Clear patterns and examples
- Ready for implementation without re-explanation

## Anti-Patterns to Avoid

### ❌ Vague Actions
```markdown
- [ ] Update the service layer
- [ ] Fix the API calls
- [ ] Handle errors better
```

### ✅ Specific Actions
```markdown
- [ ] Update `UserService.fetchUser()` to accept `version` parameter (line 23)
- [ ] Change API endpoint from `/users` to `/v2/users` in `ApiClient.get()` (line 45)
- [ ] Add try-catch block in `handleResponse()` to catch 404 errors (line 67)
```

### ❌ Implementation Details in Wrong Section
Don't put technical implementation in "Context" or "Summary"

### ✅ Proper Separation
- Context = Why this work exists
- Actions = What to do
- Summary = What breaks
- Key Pattern = How to do it

### ❌ Assuming Knowledge
Don't assume how things work - read the code and ask

### ✅ Verify First
Read the actual code, trace dependencies, ask clarifying questions

## Success Criteria

A good plan:
- ✅ Can be executed without asking "what did they mean?"
- ✅ Has clear file paths and line numbers
- ✅ Shows concrete code examples
- ✅ Explains the migration order and why
- ✅ Has no unresolved questions
- ✅ References existing patterns and services
- ✅ Warns about pitfalls (circular deps, race conditions, etc.)

A bad plan:
- ❌ Uses vague language ("update things", "fix issues")
- ❌ Lacks file paths or line numbers
- ❌ Has unresolved questions
- ❌ Ignores existing patterns
- ❌ No code examples
- ❌ Unclear migration order

## Example Action Items

### Good Examples
```markdown
- [ ] **RENAME** `getHierarchies(versionId: string): Observable<GetAllHierarchiesDto>` 
      to `getPolicyHierarchy(versionId: string): Observable<HierarchyObjectGetDto>`
  - Returns a single policy object instead of an array of hierarchies
  - Update endpoint: `hierarchies?versionId=${versionId}` → `versions/${versionId}/policy`

- [ ] **UPDATE** `createVariableWithHierarchy()` (lines 97-110):
  - [ ] **REMOVE** call to `hierarchiesStore.createVariableRef()` (lines 105-108)
  - [ ] **ADD** call to `hierarchiesStore._getHierarchies(versionId())` after variable creation
  - [ ] Use `flatHierarchies()` signal to find the variable ref ID

- [ ] Add `versionId` parameter to all methods:
  - [ ] `createHierarchy(versionId: string, hierarchy: HierarchyCreateDto)`
  - [ ] `updateObjectName(versionId: string, objectId: string, name: string)`
  - [ ] `deleteHierarchy(versionId: string, hierarchyId: string)`
```

### Note Formatting
```markdown
**Note**: The variable ref will be placed by the backend under the 
root policy object level by default. We need to refresh hierarchies 
to find its ID, then move it to the desired parent.

**Important**: Be careful of circular dependencies between hierarchies 
store and variables store! The `RepositoryFlatHierarchiesService` was 
designed to avoid this by creating computed signals.
```

## Integration with Development Workflow

### When to Create a Plan
- Before starting complex migrations
- When backend APIs change
- When refactoring affects multiple files
- When the change has cross-cutting concerns
- When you need to align with the team on approach

### When NOT to Create a Plan
- Simple bug fixes (1-2 file changes)
- Trivial updates (typos, formatting)
- Changes fully documented in ticket/issue
- Exploratory work (spikes, POCs)

### Plan as Living Document
- Plans can be updated during implementation
- Mark completed items with `- [x]`
- Add "Implementation Notes" section if needed
- Document deviations from the original plan

## Metadata

**Skill Type**: Planning & Analysis  
**Output Format**: Markdown  
**Output Location**: `~/.agentic/plans/` directory  
**Interaction Style**: Question-driven, iterative refinement  
**Success Metric**: Plan can be executed without clarification
