# Clarify Implementation Tickets

This folder contains Ralph Wiggum-compatible tickets for implementing the Clarify app.

## Structure

```
tickets/
  todo/       # Tickets ready to be worked on
  complete/   # Completed tickets (move here when done)
```

## Using with Ralph Wiggum

### Start a ticket

```bash
# Start Ralph loop with a specific ticket
claude --print "$(cat plans/tickets/todo/001-supabase-project-setup.md)" | /ralph-wiggum:ralph-loop
```

### Workflow

1. Pick the lowest-numbered ticket with all dependencies complete
2. Run Ralph with that ticket
3. When Ralph outputs the completion promise, move ticket to `complete/`
4. Repeat

### Ticket Format

Each ticket contains:

- **Dependencies**: Other tickets that must be complete first
- **Task**: What to build
- **PRD Reference**: Link to full PRD for context
- **Implementation Details**: Code snippets (SQL, TypeScript)
- **Files to Create/Modify**: Expected file paths
- **Acceptance Criteria**: Checkboxes for verification
- **Completion Promise**: Signal for Ralph to emit when done

### Dependency Rules

- Tickets 001, 008, 037 have no dependencies (can start in parallel)
- Database tickets (002-007) depend on 001
- Most app tickets depend on 008 (Expo scaffold)
- Check each ticket's Dependencies section before starting

### Completion Verification

When Ralph emits `<promise>TICKET_XXX_COMPLETE</promise>`:

1. Verify all acceptance criteria are checked
2. Run any tests mentioned in the ticket
3. Move file from `todo/` to `complete/`
4. Commit changes

## PRD Reference

Full product requirements: `plans/clarify-prd.md`

## Bootstrapping Notes

**Supabase is already configured!** The `.env` file contains all credentials:

```
SUPABASE_PROJECT_URL=https://jnnhttmrjvgrpsoerzvi.supabase.co
NEXT_PUBLIC_SUPABASE_URL=...
EXPO_PUBLIC_SUPABASE_URL=...
DATABASE_URL=...
```

### Starter Templates

- **Next.js (web)**: Use Vercel's Supabase starter - `npx create-next-app -e with-supabase clarify-web`
- **Expo (mobile)**: Use tabs template - `npx create-expo-app clarify-app --template tabs`

Ticket 001 verifies Supabase config, ticket 008 creates Expo app, ticket 037 creates Next.js app.

## Phase Overview

| Phase | Tickets | Focus |
|-------|---------|-------|
| 1 | 001-008 | Foundation (Supabase, DB, Expo) |
| 2 | 009-012 | Auth & Onboarding |
| 3 | 013-019 | Question Types |
| 4 | 020-023 | Quiz Taking |
| 5 | 024-028 | AI Integration |
| 6 | 029-031 | Insights & Profile |
| 7 | 032-036 | Social Features |
| 8 | 037-041 | Sharing & Deep Links |
| 9 | 042-044 | Notifications |
| 10 | 045-050 | Monetization & Polish |
