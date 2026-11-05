#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
config="$PWD/cliff.toml"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/opensesame-release-notes.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT

# All commits and tags live in this disposable fixture, never the checkout.
git init --quiet --initial-branch fixture "$fixture"
cd "$fixture"
git config core.hooksPath /dev/null
commit() {
    git -c user.name=Fixture -c user.email=fixture@example.invalid \
        -c commit.gpgsign=false commit --quiet --allow-empty -m "$1"
}
notes() { git-cliff --config "$config" --current --strip header; }

commit 'feat: first release only'
git -c tag.gpgsign=false tag v0.1.0
first="$(notes)"
[[ "$first" == *'### Features'* && "$first" == *'first release only'* ]]

commit 'feat: unscoped feature'
commit 'feat(menu): scoped feature'
commit 'fix(focus): focus correction'
commit 'perf: faster hovering'
commit 'refactor(core): simplify timer'
commit 'docs: document controls'
commit 'ci: update checks'
commit 'build: package app'
commit 'style: format sources'
commit 'handwritten release entry'
commit 'test(core): hidden test changes'
commit 'chore(deps): hidden dependency changes'
commit 'Merge pull request #1 from fixture'
commit 'fix: resolve merge conflict'
commit 'feat(api)!: remove old interface'
commit $'chore: migrate settings\n\nBREAKING CHANGE: remove old settings key'
git -c tag.gpgsign=false tag v0.2.0
second="$(notes)"
remaining="$second"
for group in Features 'Bug fixes' Performance Refactor Docs CI Build Style Others; do
    [[ "$remaining" == *"### $group"* ]]
    remaining="${remaining#*"### $group"}"
done
for message in 'unscoped feature' '**menu:** scoped feature' '**focus:** focus correction' \
    'handwritten release entry' '**BREAKING:** **api:** remove old interface' \
    '**BREAKING:** migrate settings'; do
    [[ "$second" == *"$message"* ]]
done
for excluded in 'first release only' 'hidden test changes' 'hidden dependency changes' \
    'Merge pull request' 'merge conflict' '<!--'; do
    [[ "$second" != *"$excluded"* ]]
done
# The old tag must still generate its own notes even when newer tags exist.
git checkout --quiet v0.1.0
[[ "$(notes)" == "$first" ]]
# A preview contains only changes since the last release.
git checkout --quiet fixture
commit 'fix: unreleased correction'
preview="$(git-cliff --config "$config" --unreleased --strip header)"
[[ "$preview" == *'unreleased correction'* && "$preview" != *'unscoped feature'* ]]
printf '%s\n' '4 release-note checks passed (first release, groups and filters, selected tag, unreleased preview).'
