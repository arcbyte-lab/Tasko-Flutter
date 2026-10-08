---
title: AGENTS — where this repo ends and the thinking starts
kind: meta
updated: 2026-10-08
---

# How an AI works in this repo

This repo holds Tasko's **Flutter app**. The server API is a separate repo,
`arcbyte-lab/Tasko-API`. Both have a sibling thinking space, Arcbyte, which
holds the product vocabulary, specs, and decisions. That split is
deliberate — see Arcbyte's own
[AGENTS.md](../../arcbyte/AGENTS.md): "Arcbyte holds thinking, not code."
Neither repo's rules apply inside the other.

On this machine, Arcbyte lives at `~/Projects/arcbyte`, this repo at
`~/Projects/Dev/Tasko-Flutter`. The paths below (`../../arcbyte/...`) are for
a human or AI reading this file locally, not a build dependency; nothing here
should import across that path, and CI must not assume Arcbyte is checked
out.

## The domain model lives in Arcbyte, not here

Tasko has no `CONTEXT.md` yet. Until it does, its vocabulary is in
`../../arcbyte/ideas/tasko/decisions/` (0002 names **Workspace**, **Project**
and the tabs) and its tables in
`../../arcbyte/ideas/tasko/assets/sqlite-schema.sql`
([decision 0001](../../arcbyte/ideas/tasko/decisions/0001-adopt-sqlite-schema-over-schema-zero.md)).
Use those exact names for types, files, and variables wherever the code names
a domain concept.

- **Code implements the domain model. It does not define it.** If you need a
  concept Arcbyte has no word for yet, don't invent one locally and move on.
  Say so, and get the term added in Arcbyte first — then use it here.
- If a term stops fitting what the code needs, that's the model drifting,
  not a reason to quietly rename it in code. Flag it back to Arcbyte.
- Purely technical vocabulary — a repository, a Cubit, a widget — is exempt.

## Specs and decisions live in Arcbyte too

- **What to build** — specs under `../../arcbyte/ideas/tasko/hipster/` and
  `.../hacker/`. Read the spec before implementing the feature it describes.
  The visual spec is the
  [hifi mockup tickets](../../arcbyte/ideas/tasko/hipster/hifi-mockup-tickets-for-pen-dev.md);
  the build tickets are
  [v1 home build tickets](../../arcbyte/ideas/tasko/hacker/v1-home-build-tickets.md).
- **What is already built** —
  [Flutter app, as built](../../arcbyte/ideas/tasko/hacker/flutter-app-as-built.md).
  Keep it current when the app's shape changes.
- **Talking to the server** — one seam, `TasksApi`, currently backed by
  `FakeTasksApi`. The server decides permissions (`canReview`, `canArchive`,
  `canRequestExtension`); the app shows what it is told, it does not
  re-derive reviewer rules
  ([0004](../../arcbyte/ideas/tasko/decisions/0004-checkbox-goes-to-review-only-when-needed.md)).
- **Why a product choice was made** — `../../arcbyte/ideas/tasko/decisions/`,
  numbered and dated. Don't re-litigate a settled decision here.
- A decision purely about this repo's own code shape can live here as a
  normal ADR. If it changes what the product does, it belongs in Arcbyte.

## Everything else

Normal engineering rules apply here — tests, conventions, tooling — same as
any code repo. Nothing in Arcbyte's `AGENTS.md` (lenses, `evidence:` fields,
`status: draft`, etc.) is relevant on this side.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (`arcbyte-lab/Tasko-Flutter`), via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default triage label vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

No local `CONTEXT.md`/`docs/adr/` — domain vocabulary, specs, and decisions live in the sibling Arcbyte repo, per the domain-model rule above. See `docs/agents/domain.md`.
