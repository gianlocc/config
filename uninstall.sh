#!/usr/bin/env bash
#
# Undo what setup.sh did. Two levels:
#
#   ./uninstall.sh           roll the system back one generation, restore your
#                            dotfiles, unhook git. Nix and nix-darwin stay.
#
#   ./uninstall.sh --purge   the above, plus remove nix-darwin entirely via
#                            darwin-uninstaller and hand /etc/nix back to
#                            Determinate. Nix itself is still not touched.
#
# Neither mode uninstalls Nix. To go that far, run the Determinate uninstaller
# by hand afterwards: `/nix/nix-installer uninstall`.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!!  %s\033[0m\n' "$*"; }
ok() { printf '    %s\n' "$*"; }

PURGE=false
[[ "${1:-}" == "--purge" ]] && PURGE=true

################################################################################
say "1/4  unhooking git"
################################################################################
# Drops back to the global hooksPath (work-book/githooks), which was never
# modified. `git pull` here stops triggering rebuilds.
if git config --local --get core.hooksPath >/dev/null 2>&1; then
  git config --local --unset core.hooksPath
  ok "removed repo-local core.hooksPath"
else
  ok "no repo-local hooksPath set"
fi
rm -f .git/last-synced
ok "cleared sync state"

################################################################################
say "2/4  restoring dotfiles"
################################################################################
# home-manager replaces these with symlinks and keeps the original as
# <file>.hm-bak. Put the originals back; where there is no backup, just drop
# the symlink (the content still lives in this repo's dotfiles/).
restore() {
  local rel="$1"
  local f="$HOME/$rel"
  local bak="$f.hm-bak"

  if [[ -L "$f" ]]; then
    rm -f "$f"
    if [[ -e "$bak" ]]; then
      mv "$bak" "$f"
      ok "restored ~/$rel from backup"
    else
      ok "removed managed symlink ~/$rel (no backup; content is in dotfiles/)"
    fi
  elif [[ -e "$bak" && ! -e "$f" ]]; then
    mv "$bak" "$f"
    ok "restored ~/$rel from backup"
  else
    ok "~/$rel not managed here, left alone"
  fi
}

for f in .zshrc .zshenv .zprofile .gitconfig .p10k.zsh .gitignore_global \
  .config/cmux/cmux.json .config/tmux/tmux.conf .config/ghostty \
  .claude/settings.json .claude/CLAUDE.md; do
  restore "$f"
done

# Directories home-manager creates that nothing else owns.
rm -rf "$HOME/.zsh/plugins"
rm -rf "$HOME/Library/Fonts/HomeManager"
ok "removed ~/.zsh/plugins and ~/Library/Fonts/HomeManager"

################################################################################
say "3/4  reverting the system"
################################################################################
if [[ "$PURGE" == true ]]; then
  if command -v darwin-uninstaller >/dev/null 2>&1; then
    warn "removing nix-darwin entirely"
    sudo darwin-uninstaller || warn "darwin-uninstaller failed; see above"
  else
    warn "darwin-uninstaller not found; skipping"
  fi
else
  # Generation 1 predates this repo, so a rollback lands on whatever the
  # machine had before. If there is nothing to roll back to, say so rather
  # than failing.
  gens=$(sudo nix-env -p /nix/var/nix/profiles/system --list-generations 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$gens" -gt 1 ]]; then
    sudo darwin-rebuild --rollback
    ok "rolled back to the previous generation"
  else
    warn "only one system generation exists; nothing to roll back to."
    warn "use --purge to remove nix-darwin altogether."
  fi
fi

################################################################################
say "4/4  restoring /etc/nix/nix.conf"
################################################################################
BACKUP="/etc/nix/nix.conf.pre-configs"
if [[ -f "$BACKUP" ]]; then
  sudo cp "$BACKUP" /etc/nix/nix.conf
  ok "restored nix.conf from $BACKUP"
else
  ok "no backup found; leaving nix.conf as-is"
fi

say "done"
cat <<'EOF'

  Open a new shell to pick up the restored ~/.zshrc.

  Still installed on purpose: Nix itself. To remove that too:
      /nix/nix-installer uninstall

EOF
