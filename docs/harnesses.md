# Harness support

The kit has one canonical source for project guidance and separate integrations
for each coding agent harness. Keep the project rules in `skills/`, `agents/`
and `commands/`; an integration adapts those files to the format and capabilities
the harness actually reads.

## Current integrations

| Harness | Skills | Agents | Commands | Integration |
| --- | --- | --- | --- | --- |
| Claude Code | Native skill folders | Markdown subagents | Markdown commands / skills | Claude Code plugin or copies |
| Codex | Shared skill folders | Generated TOML custom agents | Generated skill folders | `install.sh` |
| Kimi Code | Shared skill folders | Adapted Markdown agents | Flat skill files | `install.sh` |
| opencode | Shared skill folders | — | — | `install.sh` |
| GitHub Copilot | Shared skill folders | — | — | `install.sh` |

The source formats are not all interchangeable. Codex agents need TOML, while
Kimi uses different tool names and paths and has no commands directory. Keep
those differences in the integration, rather than adding harness-specific
instructions to the canonical source files.

## Shared workflow contract

The same work should have the same scope, safety boundaries, handoff and report
in every harness. Instructions describe those outcomes first; each adapter
maps them to native syntax and the capabilities that are available.

- **Skills** hold reusable domain knowledge and procedures. Keep the common
  skills in the Agent Skills folder format (`name`, `description`, Markdown
  body, and any relative references). All three harnesses can read this format.
- **Agents** describe roles, their allowed work, and the handoff they return.
  Give each delegated task one deliverable and a clear file boundary. The
  caller remains responsible for combining results and checking completion.
- **Isolation** is required when delegated workers edit the same repository.
  Use native worktree isolation where available; otherwise create a git
  worktree and start the worker there. Keep dependent tasks sequential.
- **Resuming** is optional. Preserve the returned result and the user's answer
  in the next handoff if the harness cannot resume the same worker.
- **Tools and permissions** are not fully portable. Claude Code and Kimi can
  express tool allowlists in agent front matter. Generated Codex agents inherit
  the active session's tools and permissions in this kit. Role instructions
  such as “read-only” therefore describe the required behaviour; they are not
  an equally enforced permission boundary in all three harnesses.
- **Hooks** are not part of the shared kit interface. The main project has
  Claude-specific hooks; the installer does not configure equivalent Codex or
  Kimi hooks. When a hook provides an automatic check, the matching skill names
  the same command to run manually when that hook is unavailable.
- **Commands** name workflows, not capabilities. Claude commands and Kimi
  flat skills can accept arguments; Codex commands are rendered as skill
  folders. The body should specify the task input and expected result, not
  assume a particular subagent API or slash-command spelling.

Model choice is also harness-specific. Shared role files use inherited model
selection and avoid naming a model family. Keep task quality criteria and
evidence requirements in the role itself; let users configure the model and
reasoning level in the harness.

The guides for these integrations are [Claude Code subagents and skills](https://code.claude.com/docs/en/sub-agents),
[Codex subagents and custom agents](https://learn.chatgpt.com/docs/agent-configuration/subagents),
and [Kimi Code agents](https://moonshotai.github.io/kimi-code/en/customization/agents)
and [skills](https://moonshotai.github.io/kimi-code/en/customization/skills).

## Adding or changing an integration

1. Check the harness's current documentation and record which file formats,
   discovery paths and invocation forms it supports. Link the documentation
   used; do not infer support from another harness's conventions.
2. Map each canonical source type to a native target. Mark unsupported types
   explicitly instead of silently omitting them.
3. Keep any format conversion at the integration boundary. Preserve the
   meaning of the source instructions; document adaptations that change tools,
   delegation, paths or invocation.
4. Update the support table here and the user-facing table in `README.md`.
   Keep install and uninstall destinations aligned with the main repository's
   ignore rules.
5. Follow `AGENTS.md`'s scratch-checkout procedure for installer changes. A
   harness integration must preserve the installer's ownership rule: update or
   remove only files recorded in its manifest.

The installer currently implements these adapters in `install.sh`. If the
number or complexity of integrations grows, move each renderer into a focused
adapter script and leave manifest ownership and safe file operations in the
installer. Avoid a generic conversion framework until multiple integrations
need the same well-defined behavior.

## Examples that informed this structure

- [Microsoft TokenEconomizer](https://github.com/microsoft/TokenEconomizer)
  separates a shared implementation from harness-specific plugin packaging
  and documents supported harnesses. Its runtime plugin is substantially
  larger than this kit, so its overall layout is not a template to copy.
- [Superpowers](https://github.com/obra/superpowers) keeps shared skills while
  providing integrations for several harnesses and documents harness-specific
  porting constraints. This supports keeping reusable guidance separate from
  native adapters.

These examples inform the boundary, not a requirement to support every harness
or to make every integration a plugin.
