---
name: create-pr
description: Creates a pull request using gh CLI with smart commit analysis. Use this when a PR needs to be created.
---

# Create Pull Request Skill

## Purpose
Automatically create well-structured pull requests with meaningful descriptions based on git commit analysis. The PR description focuses on **why** changes were made, not just **what** was changed, and includes ticket references when applicable.

## When to Use This Skill
- When changes are committed and ready for review
- When a feature/fix is complete and needs to be merged
- When user explicitly asks to create a PR
- After completing work on a branch

## Prerequisites
- Git repository with commits ready to push
- GitHub CLI (`gh`) installed and authenticated
- Working branch different from the base branch (typically `main` or `develop`)

## Behavior

### 1. Analyze Changes
Before creating the PR:
- Run `git log` to review commits since branching
- Run `git diff` against base branch to understand scope
- Identify the **purpose** of changes from commit messages and diff
- Look for non-trivial implementation details worth mentioning

### 2. Extract Ticket Reference
If provided with a ticket/issue URL:
- Extract ticket ID from URLs like:
  - Jira: `https://[domain].atlassian.net/browse/[TICKET-ID]` → `[TICKET-ID]`
  - GitHub: `https://github.com/[org]/[repo]/issues/[NUMBER]` → `#[NUMBER]`
  - Generic pattern: Extract alphanumeric identifier
- Format as title prefix: `[TICKET-ID] Title of PR`
- Example: `https://akur8.atlassian.net/browse/A8-14685` → `[A8-14685] ...`

### 3. Generate PR Description
Create a description that:

#### What to Include:
- **Why**: Business reason or problem being solved
- **What**: High-level summary of the solution
- **How** (only if non-trivial): Technical approaches that are noteworthy
  - New patterns introduced
  - Complex algorithms or logic
  - Architecture decisions
  - Performance optimizations
  - Breaking changes or migration steps

#### What to Avoid:
- Line-by-line change descriptions
- Obvious implementation details ("added a function", "updated import")
- File paths unless relevant to understanding
- Code snippets unless demonstrating a key pattern

#### Format:
```markdown
## Why
[Business reason or problem statement]
[Include any context provided by the user]

## What

[High-level solution summary]
[Incorporate user-provided details about the solution]

## How (if applicable)
[Non-trivial technical details]
- Key pattern/approach used
- Important architectural decisions
- Migration notes if breaking changes
- Any specific implementation notes from user context
```

### 4. Create the PR
Use `gh pr create` with:
- `--title`: Ticket prefix (if applicable) + clear, concise title
- `--body`: Generated description
- `--base`: Target branch (default: `main`, but check repository convention)
- `--web`: Open browser for final review (optional but recommended)

Example command:
```bash
gh pr create --title "[A8-14685] Add user authentication flow" \
  --body "$(cat description.md)" \
  --base main \
  --web
```

## Interaction Flow

### Step 1: Gather Context
Collect all available information:
- **User-provided context**: Any details the user shares about why/what/how
- **Ticket reference**: URL or ID if provided
- **Base branch**: Target branch (ask if unclear)
- **Git history**: Analyze commits automatically

**Important**: User context takes priority. If the user explains why they made changes or provides specific details, incorporate that directly into the PR description rather than only relying on git analysis.

### Step 2: Generate Description
- **Start with user context**: If user provided explanation, use it as the foundation
- Review commits: `git log origin/main..HEAD --oneline`
- Review changes: `git diff origin/main...HEAD --stat`
- Extract meaningful context from commit messages
- Synthesize into why/what/how format, merging git analysis with user input

### Step 3: Confirm Before Creating
Show the user:
```
Title: [A8-14685] Add user authentication flow

Description:
## Why
Users need to securely authenticate before accessing protected resources.

## What
Implemented OAuth2 authentication flow with JWT token management.

## How
- Integrated Auth0 for identity management
- Added token refresh mechanism to handle expiration
- Implemented secure token storage using httpOnly cookies

Ready to create PR? (yes/no)
```

If user provides additional context at this stage, update the description accordingly.

### Step 4: Execute
- Run `gh pr create` with the approved title and description
- Confirm success and provide PR URL

## Technical Implementation

### Extracting Ticket ID from URL
```bash
# Jira pattern
echo "https://akur8.atlassian.net/browse/A8-14685" | grep -oP '(?<=browse/)[A-Z0-9]+-[0-9]+'
# Output: A8-14685

# GitHub issue pattern  
echo "https://github.com/owner/repo/issues/123" | grep -oP '(?<=issues/)\d+'
# Output: 123 (format as #123)
```

### Analyzing Git Changes
```bash
# Get commit messages since base branch
git log origin/main..HEAD --pretty=format:"%s"

# Get summary of changes
git diff origin/main...HEAD --stat

# Get list of modified files
git diff origin/main...HEAD --name-only
```

### Smart Description Generation
1. Parse commit messages for patterns:
   - "feat:", "fix:", "refactor:" → indicates type of change
   - Issue references like "#123" or "A8-14685"
   - Key verbs: "add", "remove", "update", "fix", "improve"

2. Analyze diff for complexity:
   - Large refactors (many files) → mention architectural change
   - New dependencies → mention in "How"
   - Test additions → mention in "Testing"
   - Breaking changes → highlight prominently

3. Synthesize into narrative:
   - **Prioritize user-provided context** - if user explains the purpose, use their words
   - Start with the user/business need
   - Explain the solution approach
   - Highlight only interesting technical details
   - Incorporate any additional context the user shared (testing approach, constraints, decisions made, etc.)

## Example Scenarios

### Scenario 1: Simple Bug Fix
```
Input: git commits fixing a null pointer exception
Ticket: https://akur8.atlassian.net/browse/A8-14685

Output:
Title: [A8-14685] Fix crash on empty user profile
Description:
## Why
App crashes when users have incomplete profile data.

## What
Added null safety checks for optional profile fields.
```

### Scenario 2: Feature Implementation
```
Input: git commits adding search functionality
Ticket: https://akur8.atlassian.net/browse/A8-14690

Output:
Title: [A8-14690] Implement search with fuzzy matching
Description:
## Why
Users struggle to find items when they don't know exact names.

## What
Added search functionality with fuzzy matching and ranking.

## How
- Integrated Fuse.js for fuzzy search algorithm
- Implemented debouncing to reduce API calls
- Added search results caching for performance
```

### Scenario 3: Refactoring
```
Input: git commits restructuring component hierarchy
No ticket provided

Output:
Title: Refactor component architecture for better reusability
Description:
## Why
Components were tightly coupled, making reuse difficult and testing complex.

## What
Extracted shared logic into composable hooks and separated presentation from business logic.

## How
- Created custom hooks for state management (useAuth, useForm)
- Split components into container/presenter pattern
- Moved API calls to dedicated service layer
```

## Error Handling

### No commits to push
```
Error: No commits found on current branch
→ Suggest: Make commits first or check if you're on the right branch
```

### Not on a feature branch
```
Error: Currently on 'main' branch
→ Suggest: Create a feature branch first (git checkout -b feature/...)
```

### No gh authentication
```
Error: gh not authenticated
→ Suggest: Run `gh auth login`
```

### No ticket URL provided
```
→ Ask: "Do you have a ticket URL or ID to include in the PR title?"
→ If no: Create PR without ticket prefix
```

## Configuration Options

Allow user to specify:
- `--base <branch>`: Target branch (default: auto-detect from `main` or `develop`)
- `--draft`: Create as draft PR
- `--no-web`: Don't open browser
- `--reviewers <users>`: Add reviewers automatically
- `--labels <labels>`: Add labels to PR

## Success Criteria

A successful PR creation:
- ✅ Has clear, business-focused description
- ✅ Title includes ticket reference when applicable
- ✅ Description explains why changes were needed
- ✅ Technical details are included only when non-obvious
- ✅ PR is created without errors
- ✅ User can immediately share the PR link

A poor PR would:
- ❌ Just list files changed
- ❌ Focus only on implementation details
- ❌ Missing business context
- ❌ No explanation of why changes matter
- ❌ Missing ticket reference when one exists

## Integration with Development Workflow

### Typical Usage

#### Example 1: With User Context
```bash
User: "Create a PR for https://akur8.atlassian.net/browse/A8-14685. 
       I added authentication because we need to protect the API endpoints. 
       Used OAuth2 since it integrates with our existing identity provider. 
       Also added token refresh to avoid users getting logged out frequently."

Agent: 
1. Collecting user context... ✓
2. Analyzing commits... ✓
3. Generating description with user input... ✓
4. Creating PR with title: [A8-14685] Add user authentication
5. PR created: https://github.com/org/repo/pull/123

Description incorporated:
## Why
Need to protect API endpoints from unauthorized access.

## What
Implemented OAuth2 authentication with token refresh mechanism.

## How
- Integrated with existing identity provider
- Added automatic token refresh to prevent frequent logouts
```

#### Example 2: Without User Context
```bash
User: "Create a PR for https://akur8.atlassian.net/browse/A8-14685"

Agent: 
1. Analyzing commits... ✓
2. Generating description from git history... ✓
3. Creating PR with title: [A8-14685] Add user authentication
4. PR created: https://github.com/org/repo/pull/123
```

### Pre-flight Checks
Before creating PR, verify:
- [ ] Current branch is not the base branch
- [ ] There are unpushed commits
- [ ] Remote repository is accessible
- [ ] `gh` CLI is authenticated

## Metadata

**Skill Type**: Automation & Code Review Preparation
**Primary Tool**: GitHub CLI (`gh`)
**Secondary Tools**: `git` for analysis
**Output**: GitHub Pull Request
**Interaction Style**: Autonomous with optional confirmation
**Success Metric**: PR accurately represents the purpose and impact of changes
