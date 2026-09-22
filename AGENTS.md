# Agent Skills (OpenCode) — 365alFly

This project uses Agent Skills installed under `.opencode/skills/` (integration
of https://github.com/addyosmani/agent-skills). Shared checklists live under
`.opencode/references/`, specialist reviewer personas under `.opencode/personas/`.

## Project context

Goal: `pptx-open file.pptx` opens a `.pptx` with **real Microsoft PowerPoint**
(not LibreOffice/OnlyOffice) on Linux, with rendering fidelity identical to
Windows, in a disposable environment. Baseline architecture: WinApps
(Windows in Docker/Podman or libvirt VM + FreeRDP seamless integration).
Wine is an optional later exploration only, never the primary path. See
`AGENT_PLAN.md` and `docs/`.

Stack: Bash/POSIX shell scripts, Docker/Podman, libvirt/QEMU, FreeRDP,
Windows VM provisioning, shellcheck, bats (Bash automated testing) for
wrapper tests, GitHub Actions for CI.

## Core Rules

- If a task matches a skill, invoke it with the `skill` tool before acting.
- Skills are located in `.opencode/skills/<skill-name>/SKILL.md`.
- Follow the skill workflow strictly; do not partially apply it.
- Never skip required steps such as spec, plan, or test when a skill demands them.
- Fidelity gate: a feature is NOT done when "PowerPoint opens". It is done only
  when the rendered presentation is indistinguishable from PowerPoint on Windows.

## Intent → Skill Mapping

Map the user's intent to the matching skill automatically:

- Feature / new functionality → `spec-driven-development`, then `incremental-implementation` and `test-driven-development`
- Planning / breakdown → `planning-and-task-breakdown`
- Bug / failure / unexpected behavior → `debugging-and-error-recovery`
- Code review → `code-review-and-quality`
- Refactoring / simplification → `code-simplification`
- API or interface design → `api-and-interface-design`
- Shell/CLI tooling (this project: `wrapper/`, `scripts/`) → `api-and-interface-design` + `test-driven-development`
- VM/Docker/WinApps provisioning → `source-driven-development` (ground in official WinApps docs) + `security-and-hardening`
- CI setup → `ci-cd-and-automation`
- Docs / architecture decisions → `documentation-and-adrs`
- Performance (boot time, RDP quality) → `performance-optimization` (measure first)

## Lifecycle (implicit commands)

- DEFINE → `spec-driven-development`
- PLAN → `planning-and-task-breakdown`
- BUILD → `incremental-implementation` + `test-driven-development`
- VERIFY → `debugging-and-error-recovery`
- REVIEW → `code-review-and-quality`
- SHIP → `shipping-and-launch`

## Execution Model

For every request:

1. Determine if any skill applies (even a small chance).
2. Load the skill with `skill({ name: "<skill-name>" })`.
3. Follow the skill workflow exactly.
4. Only proceed to implementation once required steps are complete.