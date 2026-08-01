# configs

Declarative macOS setup: nix-darwin + home-manager, applied automatically on `git pull`.

## Bootstrap a machine

```sh
git clone <this-repo> ~/Develop/configs
~/Develop/configs/setup.sh
```

That installs Nix and Homebrew if missing, wires up the git hooks, and applies
the config. The clone path matters — see *Load-bearing details* below.

## After that

| command | effect |
| --- | --- |
| `git pull` | applies any change that came down, automatically |
| `bin/sync --force` | applies uncommitted local edits |
| `darwin-rebuild --rollback` | undoes the last switch |
| `./uninstall.sh` | rolls back, restores dotfiles, unhooks git |
| `./uninstall.sh --purge` | the above, plus removes nix-darwin entirely |

Neither uninstall mode removes Nix itself; for that, run
`/nix/nix-installer uninstall` afterwards.

The automatic part is `core.hooksPath = hooks/` (set by `setup.sh`), plus:

- `hooks/post-merge` — fires on plain `git pull`
- `hooks/post-rewrite` — fires on `git pull --rebase`, which does *not* fire post-merge

Both call `bin/sync`, which no-ops when `HEAD` hasn't moved since the last
successful apply, so a pull with no config changes costs nothing.

## Layout

| file | what lives there |
| --- | --- |
| `flake.nix` | inputs + the single `darwinConfigurations.default` |
| `darwin.nix` | system-level: macOS defaults, Touch ID sudo, Homebrew casks |
| `home.nix` | user-level: packages, zsh/omz/p10k, dotfile symlinks |
| `dotfiles/` | gitconfig, gitignore_global, p10k.zsh, cmux.json, ghostty/, claude/ — symlinked into `$HOME` |

## What's installed

**Nix:** `git` · `gh` · `zsh` · `oh-my-zsh` · `powerlevel10k` · `tmux` · `k9s` ·
`kubectl` · `bat` · `htop` · `jq` · `direnv` · MesloLG Nerd Font, plus the
`zsh-autosuggestions` / `zsh-syntax-highlighting` plugins.

**Homebrew casks:** `cmux` (not in nixpkgs, so brew is the only declarative
option). `onActivation.cleanup = "none"` guarantees nothing not listed is ever
uninstalled — important, since most apps here were installed by hand.

**Claude Code** is bootstrapped by `setup.sh` using the official installer,
then left to update itself. It is deliberately not a nix or brew package:
nixpkgs ships 2.1.39 and the brew cask 2.1.212, while the native install moves
continuously (2.1.218 → .219 → .220 within days). A pinned package would lag and
fight the built-in updater, which cannot write into a read-only nix store. Only
its config is tracked, in `dotfiles/claude/`.

Only `settings.json` and `CLAUDE.md` are symlinked — never the whole `~/.claude`
directory, which also holds credentials, ~1.4MB of `history.jsonl` and 26
project transcripts.

## Load-bearing details

**`nix.enable = false` in `darwin.nix`.** This machine runs Determinate Nix,
which owns `/etc/nix/nix.conf`. With this off, nix-darwin generates neither
`nix.conf` nor `nix.custom.conf`, so whatever else manages those files keeps its
settings across every switch. This deliberately does *not* use Determinate's
nix-darwin module — that module regenerates `nix.custom.conf` on activation and
would silently drop any setting written there by anything else.

**The repo must live at `~/Develop/configs`.** `home.nix` points the dotfile
symlinks at that path. Cloning elsewhere builds fine but produces dangling
`~/.gitconfig` and `~/.p10k.zsh`, so `setup.sh` refuses rather than half-work.

**`~/.zshrc` is generated, not symlinked.** Editing it directly does nothing
lasting; change `programs.zsh` in `home.nix` instead. The files in `dotfiles/`
*are* symlinked via `mkOutOfStoreSymlink` and are editable in place — which
matters for `~/.p10k.zsh`, since `p10k configure` rewrites it.

**Local settings stay out of this repo.** `~/.zsh_secrets` holds credentials and
`~/.zshrc.local` holds machine- or employer-specific env vars, aliases and
paths. Neither is tracked, which is what keeps this repo publishable.

**No language toolchains in `home.nix`.** node, python, rust and go come from
per-project devshells via direnv. A global copy would shadow the pinned
versions there.
