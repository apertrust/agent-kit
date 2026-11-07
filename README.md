# Apertrust agent kit

Skills, agents and commands for working on [Apertrust](https://github.com/apertrust/apertrust) with AI coding agents. Apertrust is a free, non-destructive, cross-platform raw photo editor: darktable's processing, reimplemented on the GPU.

The kit is optional help. Nothing in the main repository turns it on, and you choose whether to install it; the rules every contribution must meet are in the main repository's `AGENTS.md`, and CI and review check them whatever you use.

The kit holds what an agent needs to work the way the project does. The skills explain how to port a darktable module, write a kernel, add an engine plugin, bind a module and shape the interface. The agents and commands split the work into small tasks: a developer, a porter, a reviewer, a tester, and a few more.

## What is in it

| Folder | Contents |
| --- | --- |
| `skills/` | Eight skills, each a folder with a `SKILL.md` and its references |
| `agents/` | Seven agents, one Markdown file each |
| `commands/` | Four commands, one Markdown file each |
| `.mcp.json` | DeepWiki's public MCP server, for questions about the projects Apertrust builds on |

The files are written for a checkout of the main repository. The paths in them (`docs/…`, `crates/…`, `tools/…`) are relative to it, so the kit is of little use on its own.

## Harnesses

| Harness | Skills | Agents | Commands |
| --- | --- | --- | --- |
| Claude Code | yes | yes | yes |
| opencode | yes | not yet | not yet |
| GitHub Copilot | yes | not yet | not yet |

opencode and Copilot both read skills from `.agents/skills/`. Their agents and commands use other formats, and the kit does not convert them yet.

## Install

Pick one way. Nothing is installed unless you do this, and nothing the kit installs is a symbolic link.

### Claude Code, as a plugin (recommended)

In Claude Code:

```text
/plugin marketplace add apertrust/agent-kit
/plugin install apertrust@agent-kit
```

The plugin's skills, agents and commands carry the plugin's name: `/apertrust:port`, `/apertrust:draft-commit` and so on.

To update, refresh the marketplace and then the plugin, and reload:

```text
/plugin marketplace update agent-kit
```

then open `/plugin`, choose the Installed tab, select `apertrust` and choose Update now (or run `claude plugin update apertrust@agent-kit` in a shell), and run `/reload-plugins`. The marketplace has auto-update off by default; turn it on from the Marketplaces tab of `/plugin` if you want it.

To remove it:

```text
/plugin uninstall apertrust@agent-kit
```

### Any harness, copies in your checkout

Clone the kit beside your checkout of Apertrust, then run its script on the checkout:

```sh
git clone https://github.com/apertrust/agent-kit.git
cd agent-kit
./install.sh ../apertrust --harness claude    # or opencode, or copilot, or all
```

The script copies files; it works in a POSIX shell, Git Bash on Windows included. What each harness reads:

| `--harness` | Copies | Into |
| --- | --- | --- |
| `claude` | skills, agents, commands | `.claude/skills/`, `.claude/agents/`, `.claude/commands/` |
| `opencode` or `copilot` | skills | `.agents/skills/` (both read it) |
| `all` (the default) | both of the above | |

The main repository's `.gitignore` ignores these folders, so the copies never show in `git status` and are never committed.

Each folder gets a manifest, `.claude/.agent-kit-installed` and `.agents/.agent-kit-installed`, listing the files the script installed, one path per line, after two comment lines with the kit's version and commit. After a `git pull` in the kit, run the same command again: it replaces the files that changed, adds new ones and removes those the kit no longer has, by the manifest. Do not edit the copies; the next run overwrites them. Add your own skills or agents under other names.

The script never touches a file it did not install. If a file with the same name is already there, it skips it and says so. To remove everything it installed, and nothing else:

```sh
./install.sh ../apertrust --harness claude --uninstall    # the same --harness as before, or all
```

### By hand

Copy `skills/<name>/` from the kit into `.claude/skills/` (Claude Code) or `.agents/skills/` (opencode and Copilot) in your checkout, and for Claude Code `agents/<name>.md` into `.claude/agents/` and `commands/<name>.md` into `.claude/commands/`. Delete them to remove them.

### DeepWiki, for orientation

The kit adds [DeepWiki](https://deepwiki.com)'s public MCP server, which answers questions about the projects Apertrust builds on: darktable, wgpu, Slang, egui and rawler. It indexes their current branches, so it is for orientation only: a port still reads darktable's source at the reference release's tag.

- **The plugin** brings it with it (`.mcp.json`).
- **A copy install** does not write it into your checkout, since Claude Code reads a project's servers from a file at the checkout's root. Add it to your own Claude Code configuration instead:

  ```sh
  claude mcp add --transport http deepwiki https://mcp.deepwiki.com/mcp
  ```

- **opencode:** add it to your own `opencode.json`:

  ```json
  { "mcp": { "deepwiki": { "type": "remote", "url": "https://mcp.deepwiki.com/mcp" } } }
  ```

### Not yet

The agents and commands for opencode and Copilot are not there yet: those harnesses get the skills only. The kit does not convert them yet.

## Checking the kit against the repository

The kit and the main repository change separately. `tools/check-paths.sh` lists every path and `tools/` command that the kit names and the checkout does not have:

```sh
tools/check-paths.sh ../apertrust
```

It exits with a non-zero status if it finds any. It skips the other projects' paths the skills name on purpose, darktable's `data/kernels/` and rawler's `data/cameras/`.

## The rules come first

The kit helps you meet the project's rules. It does not replace them. The main repository's `AGENTS.md` holds the rules that every contribution must meet, with the kit or without it. Read it first. Whoever sends a change is accountable for every line of it and must be able to explain it, however it was written.

"Decision N" in the skills and agents refers to decision N of the main repository: the file `docs/decisions/NNNN-*.md`, listed in `docs/decisions/README.md`, with the question, the options, what was chosen and why. The kit is used from a checkout of the main repository, where those files are, so read the decision before changing a rule it explains.

## Licence and contributions

GPL-3.0-or-later, as the main repository. See `LICENSE`.

Contributions are signed off under the Developer Certificate of Origin. Add the sign-off with `git commit -s`; it is one line, `Signed-off-by:` with your name and email address, and it says you have the right to submit the change under the licence.
