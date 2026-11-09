# Agent kit

The skills, agents and commands for working on [Apertrust](https://github.com/apertrust/apertrust) with AI coding agents. The README says how to install them. This file is for working on the kit itself.

## Layout

- `skills/<name>/SKILL.md`, with its `references/` and `templates/`.
- `agents/<name>.md` and `commands/<name>.md`, one file each.
- `.claude-plugin/plugin.json` and `marketplace.json`: the Claude Code plugin (name `apertrust`) and its marketplace (name `agent-kit`).
- `install.sh`: copies the kit into a checkout. `tools/check-paths.sh`: checks the kit's paths against a checkout.

## The kit follows the main repository

The files are written for a checkout of the main repository, and the paths in them (`docs/…`, `crates/…`, `tools/…`) are relative to it. Do not rewrite them to be relative to the kit.

"Decision N" in the skills and agents refers to decision N of the main repository: the file `docs/decisions/NNNN-*.md`, listed in `docs/decisions/README.md`, with the question, the options, what was chosen and why. The kit is used from a checkout of the main repository, where those files are, so read the decision before changing a rule it explains.

A change here usually follows a change in the main repository: a renamed script, a moved document, a new convention. Make it here when the main repository's change has landed. Before you open a pull request, run:

```sh
tools/check-paths.sh <main checkout>
```

It lists the paths the kit names that the checkout lacks. It skips darktable's `data/kernels/` and rawler's `data/cameras/`, which the skills name on purpose; any other path it lists is a mistake to fix. Name a file by its path only once it exists in the main repository, and describe a planned one in words.

## Installing

The kit is opt-in: nothing in the main repository turns it on, and a contributor chooses whether to install it. It reaches a checkout in two ways, the Claude Code plugin or `install.sh`, which installs copies, never symbolic links. The main repository's `.gitignore` covers the folders it writes (`.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.agents/`, `.kimi-code/`), so keep to them, and tell the main repository if the script writes anywhere else.

`install.sh CHECKOUT [--harness claude|opencode|copilot|kimi|all] [--uninstall]` records the files it installs in a manifest per target folder, `.claude/.agent-kit-installed`, `.agents/.agent-kit-installed` and `.kimi-code/.agent-kit-installed`: two comment lines (the kit's version from `.claude-plugin/plugin.json`, and its commit), then one path per line, relative to the checkout. A second run updates, adds and removes exactly the listed files, `--uninstall` removes exactly them and the manifest, and a file the script did not install is skipped, never replaced or removed. When you change the script, test on a scratch checkout: install, run again after changing and after removing a kit file, a foreign file of the same name, and uninstall leaving foreign files. Keep it POSIX (`cp -R`, `mkdir -p`, no `ln`, no GNU-only flags) so that it runs in Git Bash on Windows.

When a new kind of file joins the kit, add it to the script and to the README's table of what each harness reads.

## Formats

- **Skills:** `SKILL.md` starts with YAML front matter holding `name` (the folder's name) and `description` (what the skill does and when to use it). Opencode and Copilot read the same folder format from `.agents/skills/`.
- **Agents and commands:** Markdown with front matter, in Claude Code's format. Kimi Code reads the same agent files from `.kimi-code/agents/`, the script renaming `WebFetch` to `FetchURL` in their `tools`, and each command as a flat skill, `.kimi-code/skills/<name>.md`, named after its file; keep a command's name apart from every skill's. Opencode and Copilot get the skills only.
- **Plugin:** `.claude-plugin/plugin.json` needs `name`; the marketplace entry's `name` must equal it, and its `source` is `./`. Run `claude plugin validate .` after editing either file. Keep `version` in step with the changes you ship.

## Rules

- Scripts start with the GPL-3.0-or-later header, as comments after the shebang. The first line of the header is "Apertrust, a free, non-destructive, cross-platform raw photo editor". Copy it from `install.sh`. Scripts are POSIX `sh` with `set -eu`; run `shellcheck` if it is installed.
- Commit with `git commit -s`: every commit carries your `Signed-off-by:` (the DCO). An `Assisted-by:` or `Co-Authored-By:` trailer is allowed but never required: AI help is disclosed once, in the main repository's README.
- Never write the names of commercial raw editors.
- Never refer to private notes, private repositories or files that are not in a public repository.
- Keep commit messages and pull request descriptions short and plain. British spelling.
- The main repository's `AGENTS.md` holds the rules for contributions to Apertrust itself.
