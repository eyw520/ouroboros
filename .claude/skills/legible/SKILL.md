---
name: legible
description: Restructure a codebase so its layout and names teach its design — survey, diagnose, derive layers from the dependency graph, move, verify. Use when asked to make a repo more readable, navigable, interpretable, or semantically useful, or when a directory has grown into a wall of files.
argument-hint: [path-to-target-repo]
---

You are making a codebase legible: a reader should derive the system's structure from `ls` and a file's purpose from its name.
Target the repo at the given path, or the current one when none is given.
The whole skill defends one boundary — this is a structural change with no behavioral one.

## Phase 0 — Classify: is this repo a candidate?

Decline, and say why, when the layout is not the problem:

- **The layout is the framework's.** Where an ecosystem dictates the tree, that convention already IS the map; deviating costs a reader more than it teaches.
- **A fork of someone else's project.** A restructure guarantees merge conflicts against upstream forever.
- **Small enough that flat is legible.** A dozen peers a reader holds at once needs no packages, and adding them is ceremony.
- **No gate.** Without a green test run before and after, you cannot prove a move was pure — build the gate first, as its own work.

A published library whose import paths are its API is not a decline but a scope cut: restructure the internals, hold the public surface fixed, and say so.

## Phase 1 — Survey: measure, do not eyeball

Numbers first, because taste argues and measurements do not.

1. Peers per directory, and lines per file — the two counts that produce "wall of files" and "wall of code".
2. The internal dependency graph: who imports whom. This is the evidence every later phase reasons from.
3. The longest functions, not just the longest files — a tidy file holding one 400-line function is the worse problem.
4. The public surface: what the package exports, and which of it outside code actually imports.
5. Names that collide or nearly collide across the tree.

## Phase 2 — Diagnose: name the specific smell

Vague "it's messy" produces vague restructures. Each smell below has a different fix:

- **Flat sprawl** — tens of peers with no grouping. The fix is packages.
- **Near-collision naming** — `thing` beside `things`, `report` beside `reports`. Flatness forced those names to carry disambiguation a directory should have carried; the fix is a directory, and then better names inside it.
- **Split brain** — one concept's declaration in one directory and its implementation in another, so adding one means editing two. The fix is one folder per concept.
- **Misplaced module** — every consumer of a module lives in some other layer. The graph is telling you where it belongs.
- **The giant function** — a file whose length is one function. Layout cannot fix this; only Phase 8 can.

## Phase 3 — Derive the layers from the graph, not from taste

Group by the role each module plays in the system's story, then check the grouping against the graph you measured.

- A grouping is right when the dependency arrows point one way through it. If package A imports B and B imports A, the seam is in the wrong place.
- A module that both halves depend on stays ABOVE both. Burying a shared protocol inside one of its consumers inverts an edge — the most common way a plausible layout goes wrong.
- One or two such cross-cutting modules staying at the top level is correct, not a failure to tidy.
- Name a package for the concept a reader would go looking for, not for the pattern it implements.
- Final check: `ls` the top level and read the names aloud as a sentence about what the system does. If it does not read as one, the grouping is by mechanism rather than by role.

Accept one wrong-direction edge rather than contorting the layout around it, and say in the map why it is there.

## Phase 4 — Settle the forks before moving anything

Three decisions change the size and risk of the work, and all three are the operator's:

1. **Do tests move too?** Mirroring the source tree is the biggest navigability win and the biggest diff.
2. **Do public import paths break, or do compatibility shims stay?** Shims are non-breaking but re-create the flat surface the work removes; pre-1.0, a clean break is usually right.
3. **Is in-file decomposition in scope, or layout only?**

Ask. A restructure the operator did not size is one they will ask you to undo.

## Phase 5 — Execute as a pure move

- **`git mv`, never delete-and-create.** Blame is the other half of a codebase's documentation, and a restructure that loses it trades one kind of legibility for another. Verify with `git log --follow` afterward.
- **Rewrite imports mechanically.** Write the old-path-to-new-path map once and apply it with a script; hand-editing dozens of files is where a silent wrong import gets in.
- **No behavior change rides a move.** Spot a bug mid-move, write it down, fix it in its own commit after.
- **Hunt the references that are not imports** — they are what actually breaks: module paths inside strings (`-m package.module`), entry points and scripts, test monkeypatch targets, plugin discovery that scans a package's path, config globs, CI paths, and code snippets in docs.

## Phase 6 — Give every directory its own map

- A package's index file (`__init__`, `mod`, `index`) carries a docstring naming what each module in it is for, one dense line each. This is the artifact that makes a tree teach; a package that only groups files has done half the job.
- **Do not turn index files into re-export façades.** That creates a second public surface to keep in sync and invites import cycles between sibling packages. Keep one public surface at the root, and let internal code import from the module that owns the name — explicit paths tell the reader where things live.
- Propagate upward: a flat per-module table in the README collapses to one row per package, and the agent-facing conventions file gets a short code map pointing at it. A map that disagrees with the tree is worse than no map, so these ride the commit that moved the files.

## Phase 7 — Verify the move was pure

Each of these is cheap and each catches a failure the gate alone does not:

- **Test count identical before and after.** A moved test file silently dropped from collection is the signature failure of this work; capture the count first, compare after.
- **Public surface byte-identical.** Dump the exported names before, diff after.
- **The gate green on every commit**, not only the last — and read the real exit code, since piping to `tail` swallows it.
- **Smoke the real entry points** against real data, not only tests: a CLI's every subcommand, a service's health path. Import-time breakage from a move often passes a mocked test suite.
- Once a test tree mirrors a source tree, the same basename repeats across directories, and most runners key test modules by basename — expect that collision and configure the runner for it.

## Phase 8 — Know where to stop

Decomposition has a floor, and crossing it makes things less legible, not more:

- Extract a block only when it has a name. A block you can only call `_part_two` is not ready to leave.
- Stop when extraction would need more parameters than the block has lines of logic — a helper with eleven arguments is the function turned inside out.
- Closures over run-local state belong where they are; hoisting them means threading that state by hand.
- A context object invented only to shorten parameter lists is the refactor eating itself. That is a design change with its own trade-offs, so it needs its own decision and its own commit — not a drive-by.

## Phase 9 — Commit and report

- One logical change per commit, following the target's convention: the move, then the test mirror, then each decomposition. Gate green before each.
- Update everything that recorded the old paths — docs, tooling config, CI, saved notes and memory. Stale paths are the debt this work is most likely to leave.
- Report what you moved, what you deliberately left (with the reason), and every scope cut. The stopping points are the most useful half of the report.
