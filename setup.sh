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

################################################################################
say "1/5  Nix"
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
say "2/5  git hooks"
################################################################################
# Repo-local, so it overrides the global core.hooksPath (which points at
# work-book/githooks) for this repo only. Tracked in git, so a fresh clone
# picks up hook changes for free.
git config core.hooksPath hooks
chmod +x hooks/* bin/* setup.sh
echo "core.hooksPath -> hooks/  (post-merge, post-rewrite)"

################################################################################
say "3/5  backing up nix.conf"
################################################################################
# This config sets nix.enable = false precisely so nix-darwin never rewrites
# /etc/nix/nix.conf. Snapshot it anyway before the first switch.
if [[ -f /etc/nix/nix.conf ]]; then
  BACKUP="/etc/nix/nix.conf.pre-configs"
  if [[ ! -f "$BACKUP" ]]; then
    sudo cp /etc/nix/nix.conf "$BACKUP"
    echo "saved $BACKUP"
  else
    echo "backup already exists: $BACKUP"
  fi
fi

################################################################################
say "4/5  applying the config"
################################################################################
"$REPO/bin/sync" --force

################################################################################
say "5/5  cleaning up imperative installs"
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

  * ~/.zshrc and ~/.gitconfig are now symlinks into dotfiles/ in this repo.
    Edit them wherever you like -- it is the same file. Commit when you care.
    Your originals were kept as ~/.zshrc.hm-bak and ~/.gitconfig.hm-bak.

  * If Exa's Rust builds start missing the cache, re-run
    ~/Develop/monorepo/bin/setup_nix.sh once. It rewrites the sccache and
    S3-cache settings, and it is idempotent.

EOF
