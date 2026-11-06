#!/bin/sh
# Apertrust, a free, non-destructive, cross-platform raw photo editor
# Copyright (C) 2026  Apertrust developers
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Copies the kit's skills, agents and commands into a checkout of Apertrust.
#
#   install.sh CHECKOUT [--harness claude|opencode|copilot|all] [--uninstall]
#
# claude    skills, agents and commands into CHECKOUT/.claude/
# opencode  skills into CHECKOUT/.agents/skills/ (agents and commands: not yet)
# copilot   the same folder as opencode (agents and commands: not yet)
#
# Copies are made, never links. Each folder the script installs into gets a
# manifest, .agent-kit-installed, listing the files it installed (one path per
# line, relative to CHECKOUT) after two comment lines naming the kit's version
# and commit. Running the script again updates exactly those files: it replaces
# the ones that changed and removes the ones the kit no longer has. --uninstall
# removes exactly them and the manifest. A file the script did not install is
# never replaced or removed; one with the same name is skipped, with a message.
set -eu

usage() {
    echo "usage: $0 CHECKOUT [--harness claude|opencode|copilot|all] [--uninstall]" >&2
    exit 2
}

kit=$(cd "$(dirname "$0")" && pwd -P)
checkout=
harness=all
uninstall=0

while [ $# -gt 0 ]; do
    case $1 in
    --harness)
        [ $# -ge 2 ] || usage
        harness=$2
        shift 2
        ;;
    --harness=*)
        harness=${1#--harness=}
        shift
        ;;
    --uninstall)
        uninstall=1
        shift
        ;;
    -h | --help)
        usage
        ;;
    -*)
        echo "unknown option: $1" >&2
        usage
        ;;
    *)
        [ -z "$checkout" ] || usage
        checkout=$1
        shift
        ;;
    esac
done

[ -n "$checkout" ] || usage
[ -d "$checkout" ] || {
    echo "not a folder: $checkout" >&2
    exit 1
}
checkout=$(cd "$checkout" && pwd -P)

claude=0
agents_folder=0
case $harness in
claude) claude=1 ;;
opencode | copilot) agents_folder=1 ;;
all)
    claude=1
    agents_folder=1
    ;;
*)
    echo "unknown harness: $harness" >&2
    usage
    ;;
esac

version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$kit/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)
commit=$(git -C "$kit" rev-parse --short HEAD 2>/dev/null || true)
version=${version:-unknown}
commit=${commit:-unknown}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
old=$tmp/old # paths the manifest lists
new=$tmp/new # paths this run leaves installed

# Whether $2 is a line of the file $1.
listed() {
    grep -Fxq -- "$2" "$1"
}

# Whether $1 is a path the script may touch inside the folder $2: relative, under
# the folder, and without "..". A hand-edited manifest cannot send it elsewhere.
safe_path() {
    case $1 in
    /* | *..*) return 1 ;;
    "$2"/*) return 0 ;;
    *) return 1 ;;
    esac
}

# Removes the empty folders above the file $1, up to but not including $2.
prune() {
    dir=$(dirname "$1")
    while [ "$dir" != "$2" ] && [ "$dir" != "." ] && [ "$dir" != "/" ]; do
        rmdir "$checkout/$dir" 2>/dev/null || break
        dir=$(dirname "$dir")
    done
}

# install_files KIT_FOLDER DEST_FOLDER PATTERN: copy the files of one kit folder
# that match PATTERN into CHECKOUT/DEST_FOLDER, a path relative to CHECKOUT.
install_files() {
    from=$kit/$1
    [ -d "$from" ] || return 0
    find "$from" -type f -name "$3" ! -name .DS_Store | sort >"$tmp/files"
    while IFS= read -r src; do
        rel=$2/${src#"$from"/}
        dest=$checkout/$rel
        if [ -f "$dest" ] && [ ! -L "$dest" ] && listed "$old" "$rel"; then
            if cmp -s "$src" "$dest"; then
                echo "present  $rel"
            else
                cp -p "$src" "$dest"
                echo "updated  $rel"
            fi
        elif [ -e "$dest" ] || [ -L "$dest" ]; then
            echo "skipped  $rel (exists, and the kit did not install it)"
            continue
        else
            mkdir -p "$(dirname "$dest")"
            cp -p "$src" "$dest"
            echo "copied   $rel"
        fi
        echo "$rel" >>"$new"
    done <"$tmp/files"
}

# sync ROOT: bring CHECKOUT/ROOT in line with the kit, or empty it of the kit's
# files with --uninstall; ROOT is .claude or .agents. The rest of the script
# fills in what each root receives before it calls this.
sync() {
    root=$1
    manifest=$checkout/$root/.agent-kit-installed
    : >"$old"
    : >"$new"
    if [ -f "$manifest" ]; then
        grep -v '^#' "$manifest" | grep -v '^$' >"$old" || true
    elif [ "$uninstall" -eq 1 ]; then
        echo "nothing installed in $root"
        return
    fi

    if [ "$uninstall" -eq 0 ]; then
        case $root in
        .claude)
            install_files skills "$root/skills" '*'
            install_files agents "$root/agents" '*.md'
            install_files commands "$root/commands" '*.md'
            ;;
        .agents)
            install_files skills "$root/skills" '*'
            ;;
        esac
    fi

    # What the manifest lists and this run does not keep: gone from the kit, or
    # everything, with --uninstall.
    while IFS= read -r rel; do
        listed "$new" "$rel" && continue
        safe_path "$rel" "$root" || {
            echo "ignored  $rel (outside $root)"
            continue
        }
        dest=$checkout/$rel
        if [ -f "$dest" ] && [ ! -L "$dest" ]; then
            rm "$dest"
            echo "removed  $rel"
            prune "$rel" "$root"
        elif [ -e "$dest" ] || [ -L "$dest" ]; then
            echo "kept     $rel (no longer the file the kit installed)"
        fi
    done <"$old"

    if [ -s "$new" ]; then
        mkdir -p "$checkout/$root"
        {
            echo "# Installed by the Apertrust agent kit: version $version, commit $commit"
            echo "# Do not edit. install.sh updates and removes exactly these files."
            sort "$new"
        } >"$tmp/manifest"
        cp "$tmp/manifest" "$manifest"
    else
        rm -f "$manifest"
        rmdir "$checkout/$root" 2>/dev/null || true
    fi
}

if [ "$claude" -eq 1 ]; then
    sync .claude
fi
if [ "$agents_folder" -eq 1 ]; then
    sync .agents
    [ "$uninstall" -eq 1 ] ||
        echo "note: agents and commands for opencode and Copilot are not supported yet"
fi
