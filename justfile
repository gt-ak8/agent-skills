# Manage symlinks of this repo's skills and agents into the Claude user config.

repo := justfile_directory()
skills_dir := env_var('HOME') / ".claude/skills"
agents_dir := env_var('HOME') / ".claude/agents"

# List skills available in this repo.
[private]
default:
    @just --list

# Install required dependencies (gum) if missing.
setup:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v gum >/dev/null; then echo "gum already installed: $(gum --version)"; exit 0; fi
    if command -v brew >/dev/null; then brew install gum; exit 0; fi
    os="$(uname -s)"; arch="$(uname -m)"
    case "$arch" in aarch64|arm64) arch=arm64;; x86_64|amd64) arch=x86_64;; *) echo "unsupported arch: $arch" >&2; exit 1;; esac
    case "$os" in Linux) os=Linux;; Darwin) os=Darwin;; *) echo "unsupported os: $os" >&2; exit 1;; esac
    ver="$(curl -fsSL https://api.github.com/repos/charmbracelet/gum/releases/latest | grep -m1 '"tag_name"' | cut -d'"' -f4)"
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    curl -fsSL "https://github.com/charmbracelet/gum/releases/download/${ver}/gum_${ver#v}_${os}_${arch}.tar.gz" -o "$tmp/gum.tar.gz"
    tar -xzf "$tmp/gum.tar.gz" -C "$tmp"
    mkdir -p ~/.local/bin
    install "$tmp"/gum_*/gum ~/.local/bin/gum
    echo "installed gum to ~/.local/bin (ensure it's on PATH): $(~/.local/bin/gum --version)"

# Interactively pick skills to symlink into ~/.claude/skills (all preselected).
link:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v gum >/dev/null || { echo "gum is required: https://github.com/charmbracelet/gum" >&2; exit 1; }
    mapfile -t skills < <(cd "{{repo}}" && for d in */SKILL.md; do echo "${d%/SKILL.md}"; done)
    [ "${#skills[@]}" -gt 0 ] || { echo "No skills found in {{repo}}" >&2; exit 1; }
    all="$(IFS=,; echo "${skills[*]}")"
    chosen="$(printf '%s\n' "${skills[@]}" | gum choose --no-limit --selected="$all" --header="Skills to link")"
    [ -n "$chosen" ] || { echo "Nothing selected."; exit 0; }
    mkdir -p "{{skills_dir}}"
    while IFS= read -r s; do
        target="{{skills_dir}}/$s"
        if [ -e "$target" ] || [ -L "$target" ]; then
            echo "skip  $s (already exists)"
        else
            ln -s "{{repo}}/$s" "$target"
            echo "link  $s"
        fi
    done <<< "$chosen"

# Symlink this repo's subagents (agents/*.md) into ~/.claude/agents.
link-agents:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    agents=("{{repo}}"/agents/*.md)
    [ "${#agents[@]}" -gt 0 ] || { echo "No agents found in {{repo}}/agents" >&2; exit 1; }
    mkdir -p "{{agents_dir}}"
    for a in "${agents[@]}"; do
        name="$(basename "$a")"
        target="{{agents_dir}}/$name"
        if [ -e "$target" ] || [ -L "$target" ]; then
            echo "skip  $name (already exists)"
        else
            ln -s "$a" "$target"
            echo "link  $name"
        fi
    done

# Interactively pick repo skills to remove from ~/.claude/skills.
unlink:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v gum >/dev/null || { echo "gum is required: https://github.com/charmbracelet/gum" >&2; exit 1; }
    mapfile -t linked < <(
        for l in "{{skills_dir}}"/*; do
            [ -L "$l" ] || continue
            case "$(readlink "$l")" in
                "{{repo}}"/*) basename "$l" ;;
            esac
        done
    )
    [ "${#linked[@]}" -gt 0 ] || { echo "No repo skills are currently linked in {{skills_dir}}"; exit 0; }
    chosen="$(printf '%s\n' "${linked[@]}" | gum choose --no-limit --header="Skills to unlink")"
    [ -n "$chosen" ] || { echo "Nothing selected."; exit 0; }
    while IFS= read -r s; do
        rm "{{skills_dir}}/$s"
        echo "unlink  $s"
    done <<< "$chosen"
