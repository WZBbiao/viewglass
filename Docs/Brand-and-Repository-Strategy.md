# Brand And Repository Strategy

## Direction

This project is no longer just a macOS GUI fork. It is evolving into:

- an AI-oriented iOS runtime inspector
- a CLI-first UI introspection toolkit
- a LookinServer-compatible runtime inspection platform

The repository should reflect that shift.

## Naming Recommendation

### Recommended umbrella name

`Viewglass`

Why:

- it suggests view hierarchy inspection, clarity, and runtime visibility
- it is not tied to only GUI or only CLI
- it works for a future platform that includes CLI, skills, MCP, and a desktop app
- it is distinct enough from the original Lookin branding

### Recommended positioning line

`Viewglass is a CLI-first runtime inspector for iOS apps, compatible with LookinServer and designed for AI workflows.`

### Naming layers

- Product / repo: `viewglass`
- CLI binary: `viewglass`
- Compatibility binary alias during migration: optional `lookin-cli` shim only if needed
- Homebrew formula after migration: `viewglass`
- MCP server name: `viewglass-mcp`
- Swift package modules:
  - `ViewglassCore`
  - `ViewglassCLI`
  - `ViewglassBridge`

## Alternative names

If `Viewglass` is unavailable or undesirable, these are viable backups:

- `RuntimeLens`
- `ViewProbe`
- `Nodeglass`

## Compatibility Policy

The project should clearly state:

- originally forked from Lookin
- compatible with LookinServer
- independently maintained by WZBBiao

Suggested wording:

`Viewglass is independently maintained and built on top of the open-source Lookin ecosystem. It remains compatible with LookinServer where practical, while adding CLI, automation, skills, and MCP support.`

## Repository Split Plan

### Phase 1: Monorepo, modernized

Keep one repo while the APIs and release flows stabilize.

Suggested target layout:

- `Sources/LookinCore`
- `Sources/LookinCLI`
- `Sources/LookinSharedBridge`
- `LookinClient`
- `Docs`
- `.github`
- `Formula`

This is the current practical structure.

### Phase 2: Public-facing rebrand

Create a new primary repo under `WZBBiao`:

- `viewglass`

This repo becomes the public home for:

- releases
- issues
- documentation
- brew formula references
- future MCP and skills guidance

The current fork can remain as a historical compatibility repo, but it should stop being the main landing page.

### Phase 3: Optional satellite repos

Only split when maintenance pressure justifies it.

Recommended future repos:

- `viewglass`
  Main product repo, monorepo, releases, docs
- `homebrew-tap`
  Formula distribution
- `viewglass-skills`
  Reusable Codex / Claude / agent skills and prompts
- `viewglass-mcp`
  Only if the MCP server becomes independently useful enough to version separately

Default recommendation: keep MCP in the main repo until it becomes operationally heavy.

## Migration Plan

### Short term

- ship `viewglass` as the primary binary
- add `Viewglass` branding to docs, release assets, and package metadata
- present the project as independently maintained
- keep Lookin compatibility explicit

### Medium term

- publish a new GitHub repo: `WZBBiao/viewglass`
- move CLI-first docs and releases there
- keep this repo as compatibility/history, or archive it after the transition
- add a binary alias strategy:
  - `viewglass`
  - optional `lookin-cli` compatibility shim for one or two release cycles

### Long term

- move the Homebrew formula to `viewglass`
- publish `viewglass-mcp`
- expose skills docs and examples
- optionally de-emphasize the old AppKit branding entirely

## Public Repo Standard

The modern public repo should include:

- clear README
- Chinese README
- CONTRIBUTING
- CODE_OF_CONDUCT
- SECURITY
- SUPPORT
- issue templates
- PR template
- release workflow
- Homebrew distribution instructions
- architecture docs

## Owner Identity

This project should present the maintainer identity as:

- GitHub: `WZBBiao`
- contact: `544856638@qq.com`

## Immediate Recommendation

Do not force a full source tree rename in the same pass.

Do this first:

1. modernize this repo
2. publish governance and roadmap
3. establish release discipline
4. create the new primary repo when the public brand is ready

That keeps technical churn low while making the strategic direction explicit.
