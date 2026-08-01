#!/usr/bin/env bash
#
# One-time bootstrap. Run this once after cloning:
#
#   git clone <repo> ~/Develop/configs && ~/Develop/configs/setup.sh
#
# After that, `git pull` applies changes on its own via the hooks installed
# below. Re-running this is harmless.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\n\033[1;33m!!  %s\033[0m\n' "$*"; }

# home.nix points the dotfile symlinks at $HOME/Develop/configs. Cloning
# somewhere else builds fine but silently produces dangling ~/.gitconfig and
# ~/.p10k.zsh symlinks, so refuse rather than half-work.
EXPECTED="$HOME/Develop/configs"
if [[ "$REPO" != "$EXPECTED" ]]; then
  warn "this repo must live at $EXPECTED (found: $REPO)"
  warn "move it there and re-run, or change \`repo\` in home.nix to match."
  exit 1
fi

# Several steps below need root. Check once, up front, rather than dying
# halfway through: without a controlling terminal sudo cannot prompt at all,
# which is what happens when this is run from an editor or agent shell.
if ! sudo -n true 2>/dev/null; then
  if [[ ! -t 0 ]]; then
    warn "this needs sudo, but there is no terminal to prompt on."
    warn "run it from a real terminal window (Ghostty, cmux, Terminal.app):"
    echo "      $REPO/setup.sh"
    exit 1
  fi
  say "0/7  sudo"
  echo "several steps need root; authenticating once up front..."
  sudo -v || { warn "could not authenticate"; exit 1; }
fi

################################################################################
say "1/7  Nix"
################################################################################
if command -v nix >/dev/null 2>&1; then
  echo "already installed: $(nix --version)"
else
  echo "installing Determinate Nix..."
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --determinate
  # Make nix visible to the rest of this script without a new shell.
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

################################################################################
say "2/7  git hooks"
################################################################################
# Repo-local, so it overrides the global core.hooksPath (which points at
# work-book/githooks) for this repo only. Tracked in git, so a fresh clone
# picks up hook changes for free.
git config core.hooksPath hooks
chmod +x hooks/* bin/* setup.sh
echo "core.hooksPath -> hooks/  (post-merge, post-rewrite)"

################################################################################
say "3/7  /etc/nix/nix.conf"
################################################################################
# This config sets nix.enable = false so nix-darwin never rewrites nix.conf --
# whatever else owns that file (Determinate, or a work bootstrap script) keeps
# its settings across every switch.
#
# The catch on a machine that previously HAD a nix-darwin-managed nix.conf:
# switching nix.enable to false makes nix-darwin delete the file it used to
# own. That silently drops `trusted-users`, which demotes your account to
# untrusted -- at which point nix ignores your substituters, trusted-public-keys
# and netrc-file, and every build starts missing the cache.
#
# So: snapshot it, and put it back if it went missing.
BACKUP="/etc/nix/nix.conf.pre-configs"
if [[ -f /etc/nix/nix.conf ]]; then
  if [[ ! -f "$BACKUP" ]]; then
    sudo cp /etc/nix/nix.conf "$BACKUP"
    echo "saved $BACKUP"
  else
    echo "backup already exists: $BACKUP"
  fi
elif [[ -f "$BACKUP" ]]; then
  warn "/etc/nix/nix.conf is missing; restoring from $BACKUP"
  sudo cp "$BACKUP" /etc/nix/nix.conf
  # trusted-users is read by the daemon, so it needs a restart to take effect.
  sudo launchctl kickstart -k system/org.nixos.nix-daemon 2>/dev/null ||
    warn "could not restart the nix daemon; reboot or restart it manually"
  echo "restored, daemon restarted"
else
  echo "no nix.conf and no backup; leaving it to Determinate"
fi

# Cheap canary: an untrusted user means the cache settings are being ignored.
if ! nix config show trusted-users 2>/dev/null | grep -qE '@admin|\b'"$USER"'\b'; then
  warn "you are not in nix's trusted-users; substituters and netrc will be ignored."
  warn "current: $(nix config show trusted-users 2>/dev/null)"
fi

################################################################################
say "4/7  Homebrew"
################################################################################
# darwin.nix declares casks, and the homebrew module needs brew to already
# exist at switch time.
if [[ -x /opt/homebrew/bin/brew ]]; then
  echo "already installed: $(/opt/homebrew/bin/brew --version | head -1)"
else
  echo "installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

# Most of these apps were installed by hand, and brew refuses to install over
# an existing app ("It seems there is already an App at ..."), which would fail
# the switch. `--adopt` takes ownership of what's already there instead.
#
# The cask list is read back out of the flake so this never drifts from
# darwin.nix. --adopt is harmless when the app isn't installed yet.
# casks are submodules, not plain strings, so pull .name out in Nix rather
# than trying to unpick the JSON in shell.
CASKS=$(nix eval --raw "$REPO#darwinConfigurations.default.config.homebrew.casks" \
  --apply 'cs: builtins.concatStringsSep " " (map (c: c.name) cs)' 2>/dev/null)
for cask in $CASKS; do
  if brew list --cask "$cask" >/dev/null 2>&1; then
    echo "already brew-managed: $cask"
  else
    echo "adopting/installing cask: $cask"
    brew install --cask --adopt "$cask" ||
      warn "could not install '$cask'; the switch may fail until this is resolved"
  fi
done

################################################################################
say "5/7  Claude Code"
################################################################################
# Deliberately NOT installed via nix or brew. nixpkgs ships 2.1.39 and the brew
# cask 2.1.212, while the native installer self-updates continuously (2.1.218 ->
# .219 -> .220 within days here). A pinned package would sit behind and fight
# the built-in updater, which cannot write into a read-only nix store anyway.
#
# So: bootstrap it with the official installer, then let it update itself. Only
# its config is version-controlled, in dotfiles/claude/.
if command -v claude >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/claude" ]]; then
  echo "already installed: $("$HOME/.local/bin/claude" --version 2>/dev/null || echo present)"
else
  echo "installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash ||
    warn "Claude Code install failed; see https://docs.claude.com/en/docs/claude-code"
fi

################################################################################
say "6/7  applying the config"
################################################################################
"$REPO/bin/sync" --force

################################################################################
say "7/7  cleaning up imperative installs"
################################################################################
# These are now declared in home.nix. Leaving the `nix profile` copies around
# means two sources of truth and a stale binary shadowing the managed one.
for pkg in direnv nix-direnv cachix; do
  if nix profile list 2>/dev/null | grep -qE "^Name:.*\b${pkg}\b"; then
    echo "removing '${pkg}' from the imperative nix profile"
    nix profile remove "$pkg" 2>/dev/null || warn "could not remove ${pkg}; do it by hand"
  fi
done

################################################################################
say "done"
################################################################################
cat <<'EOF'

  Day-to-day from here:

    git pull              applies any config change automatically
    bin/sync --force      apply local edits you have not committed
    darwin-rebuild --rollback   undo the last switch

  Two things worth knowing:

  * ~/.zshrc is now GENERATED from home.nix -- editing it directly does
    nothing lasting. Change programs.zsh in home.nix and re-sync instead.
    ~/.gitconfig, ~/.p10k.zsh and cmux.json are symlinks into dotfiles/ and
    ARE editable in place. Originals were kept as <file>.hm-bak.

  * Your ~/.oh-my-zsh clone and ~/.tmux.conf are no longer used and can be
    deleted once the new shell looks right.

  * Machine- or work-specific env vars, aliases and paths belong in
    ~/.zshrc.local (sourced automatically, never tracked here). Credentials
    belong in ~/.zsh_secrets.

EOF
