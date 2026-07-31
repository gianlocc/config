# configs

Declarative macOS setup: nix-darwin + home-manager, applied automatically on `git pull`.

## Bootstrap a machine

```sh
git clone <this-repo> ~/Develop/configs
~/Develop/configs/setup.sh
```

That installs Nix if missing, wires up the git hooks, and applies the config.

## After that

| command | effect |
| --- | --- |
| `git pull` | applies any change that came down, automatically |
| `bin/sync --force` | applies uncommitted local edits |
| `darwin-rebuild --rollback` | undoes the last switch |

The automatic part is `core.hooksPath = hooks/` (set by `setup.sh`), plus:

- `hooks/post-merge` — fires on plain `git pull`
- `hooks/post-rewrite` — fires on `git pull --rebase`, which does *not* fire post-merge

Both call `bin/sync`, which no-ops when `HEAD` hasn't moved since the last
successful apply, so a pull with no config changes costs nothing.

## Layout

| file | what lives there |
| --- | --- |
| `flake.nix` | inputs + the single `darwinConfigurations.default` |
| `darwin.nix` | system-level: macOS defaults, Touch ID sudo, GUI apps (off) |
| `home.nix` | user-level: CLI packages, dotfile symlinks |
| `dotfiles/` | `.zshrc`, `.gitconfig` — symlinked into `$HOME`, editable in place |

## What's installed

`git` · `zsh` · `oh-my-zsh` · `powerlevel10k` · `tmux` · `k9s` · `kubectl` ·
`bat` · `htop` · `jq`, plus `direnv` (load-bearing for the monorepo devshells)
and the `zsh-autosuggestions` / `zsh-syntax-highlighting` plugins.

Two things on the wish-list are not installable this way:

- **cmux** is a GUI app and is not in nixpkgs. Only `~/.config/cmux/cmux.json`
  is managed here.
- **claude-code** is in nixpkgs at 2.1.39 while the self-updating install in
  `~/.local/share/claude/versions` is far ahead. Adding it would shadow the
  newer build with an older one, so it is left commented out in `home.nix`.

## Things that are load-bearing

**`nix.enable = false` in `darwin.nix`.** This machine runs Determinate Nix, and
Exa's `monorepo/bin/setup_nix.sh` appends the `exa-nix-s3-cache-1` trusted key
and the sccache `extra-sandbox-paths` setting to the live nix config. If
nix-darwin managed `/etc/nix/nix.conf` it would regenerate that file on every
switch and drop both, quietly killing cache hits on Rust builds. Leave it off.

**Dotfiles use `mkOutOfStoreSymlink`.** `~/.zshrc` points at the working copy in
`dotfiles/`, not a read-only nix store path. Edit it directly like a normal
file; no rebuild needed for a dotfile change.

**No language toolchains in `home.nix`.** node, python, rust and go come from
the monorepo devshells via direnv. A global copy would shadow the pinned
versions there.

**GUI apps are not managed.** The `homebrew` block in `darwin.nix` is commented
out on purpose — there are ~40 hand-installed apps in `/Applications`, several
with self-updaters or system extensions, and enabling it would have brew try to
adopt all of them. Turn it on a few casks at a time if you ever want it.
