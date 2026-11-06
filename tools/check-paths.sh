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

# Lists every repository path that the kit's skills, agents and commands name
# and that does not exist in a checkout of Apertrust. Exits 1 if there are any.
#
#   tools/check-paths.sh CHECKOUT
#
# A path is any word with a slash whose first element is a top-level folder of
# the checkout (docs/, crates/, tools/, data/ ...), or one of its root files
# (AGENTS.md, Cargo.toml ...), in prose, code spans or code blocks alike.
# Placeholders (<name>, {a,b}, globs, "...") end a path: `crates/op/<id>/src`
# must at least have crates/op/. Paths of other trees that share a first
# element are skipped where the kit names them: darktable's data/kernels/ and
# rawler's data/cameras/. Any other such path is reported; read the list.
set -eu

[ $# -eq 1 ] && [ -d "$1" ] || {
    echo "usage: $0 CHECKOUT" >&2
    exit 2
}
checkout=$(cd "$1" && pwd -P)
kit=$(cd "$(dirname "$0")/.." && pwd -P)

words=$(mktemp)
trap 'rm -f "$words"' EXIT

# Every candidate word in the kit's Markdown files, one per line with its file.
find "$kit/skills" "$kit/agents" "$kit/commands" -name '*.md' | sort |
    while read -r file; do
        grep -oE '[A-Za-z0-9_.<>{}*…-]+(/[A-Za-z0-9_.<>{}*…,-]+)+|[A-Za-z0-9_.-]+\.(md|toml|lock|json)' "$file" |
            while read -r word; do
                printf '%s\t%s\n' "${file#"$kit"/}" "$word"
            done
    done >"$words"
sort -u -o "$words" "$words"

missing=0
checked=0
report() {
    printf '%s: %s\n' "$1" "$2"
    missing=$((missing + 1))
}

while IFS="$(printf '\t')" read -r file word; do
    # The first path element must be something the checkout has, or a root file name.
    first=${word%%/*}
    case $first in
    docs | crates | tools | data | external | test-images | .claude | .github) ;;
    AGENTS.md | AGENTS.local.md | CLAUDE.md | CLAUDE.local.md | README.md | CREDITS.md | \
        Cargo.toml | Cargo.lock | deny.toml | rust-toolchain.toml | kittest.toml | .mcp.json) ;;
    *) continue ;;
    esac
    # Other projects' paths that the kit names on purpose.
    case $word in
    data/kernels | data/kernels/* | data/cameras | data/cameras/*) continue ;;
    esac
    # Cut the path at its first placeholder, glob or ellipsis, and trim punctuation.
    path=$(printf '%s' "$word" | sed 's/[<{*].*$//; s/…$//; s/[,;:.)]*$//')
    path=${path%/}
    [ -n "$path" ] || continue
    checked=$((checked + 1))
    [ -e "$checkout/$path" ] || report "$file" "$word"
done <"$words"

echo "checked $checked paths against $checkout" >&2
if [ "$missing" -gt 0 ]; then
    echo "$missing missing" >&2
    exit 1
fi
