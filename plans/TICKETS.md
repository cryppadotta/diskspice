# Implementation Tickets

This folder contains Ralph Wiggum-compatible tickets for implementing a project.

## Folder Structure

```
plans/
  SPEC.md                    # Product specification
  RALPH_INSTRUCTIONS.md      # Instructions for the executing agent
  README.md                  # This file (ticket format guide)
  tickets/
    todo/                    # Tickets ready to be worked on
    complete/                # Completed tickets (moved here when done)
```

## Ticket Format

Each ticket is a markdown file with a numbered prefix: `XXX-short-name.md`

### Required Sections

```markdown
# XXX: Ticket Title

## Dependencies
- NNN (ticket must be complete before this one can start)
- None (if no dependencies)

## Task
Brief description of what needs to be built or accomplished.

## Spec Reference
Link to relevant section in SPEC.md for full context.

## Implementation Details
Detailed instructions, code snippets, file paths, commands, etc.
Be specific enough that the agent can execute without guessing.

## Files to Create/Modify
- `path/to/new/file.swift` - Description
- `path/to/existing/file.swift` - What changes

## Acceptance Criteria
- [ ] Criterion 1 - specific, testable condition
- [ ] Criterion 2 - another condition
- [ ] Criterion 3 - etc.

## Completion Promise
\`<promise>TICKET_XXX_COMPLETE</promise>\`
```

### Writing Good Tickets

1. **Be specific**: Include exact file paths, function names, code snippets
2. **Make criteria testable**: "App compiles without errors" not "App works"
3. **Keep scope small**: One logical unit of work per ticket
4. **Include context**: Reference SPEC.md sections, explain the "why"
5. **Order dependencies correctly**: Lower-numbered tickets should be dependencies of higher ones

### Example Ticket

```markdown
# 003: Create Data Model for Folder Tree

## Dependencies
- 001 (project setup)
- 002 (Swift package structure)

## Task
Create the core data model representing the folder tree structure with size information.

## Spec Reference
See SPEC.md > Scanning Engine and Caching & Persistence sections.

## Implementation Details
Create a FolderNode model that represents a node in the file system tree:

\`\`\`swift
struct FolderNode: Identifiable, Hashable {
    let id: UUID
    let path: URL
    let name: String
    var size: Int64
    var children: [FolderNode]
    var isScanning: Bool
    var lastScanned: Date?
}
\`\`\`

## Files to Create/Modify
- `DiskSpice/Models/FolderNode.swift` - New file

## Acceptance Criteria
- [ ] FolderNode struct compiles
- [ ] Conforms to Identifiable and Hashable
- [ ] Can represent nested folder structure
- [ ] Includes scanning state tracking

## Completion Promise
\`<promise>TICKET_003_COMPLETE</promise>\`
```

## Running Ralph

### Start the execution loop

```bash
# Point Ralph at the instructions
cat plans/RALPH_INSTRUCTIONS.md | claude
```

### Manual workflow

1. Pick the lowest-numbered ticket with all dependencies in `complete/`
2. Execute the ticket
3. Verify all acceptance criteria pass
4. Move ticket: `mv plans/tickets/todo/XXX-*.md plans/tickets/complete/`
5. Commit: `git add -A && git commit -m "Complete ticket XXX: [title]"`
6. Repeat

## Dependency Graph Tips

- Tickets 001-00N with no dependencies can run in parallel
- Database/model tickets should come before UI tickets
- Scaffold/setup tickets should be early (001-005 range)
- Polish/optimization tickets should be late (high numbers)

## Status Commands

```bash
# Count remaining vs complete
echo "TODO: $(ls plans/tickets/todo/*.md 2>/dev/null | wc -l)"
echo "DONE: $(ls plans/tickets/complete/*.md 2>/dev/null | wc -l)"

# List tickets in dependency order
ls -1 plans/tickets/todo/*.md | sort -t- -k1 -n

# Find tickets with no dependencies
grep -l "^- None" plans/tickets/todo/*.md
```
