{ pkgs, lib, config, username, ... }:

let
  # Where this repo lives. Dotfiles are symlinked out of the *working copy*
  # (not the nix store) so they stay editable in place -- which matters for
  # ~/.p10k.zsh, since `p10k configure` rewrites it.
  repo = "${config.home.homeDirectory}/Develop/configs";
in
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";
  home.stateVersion = "25.05";

  ##############################################################################
  # Tools.
  #
  # Language toolchains ARE global here, by choice. The usual worry is that a
  # global node/python shadows a project's pinned one -- verified not to happen:
  # direnv *prepends* the devshell to PATH on directory entry, so inside e.g. a
  # monorepo every tool still resolves to the devshell copy, even where the
  # global version is newer. Checked against git, gh, jq, kubectl, node, python3,
  # rustc, cargo and go.
  ##############################################################################
  home.packages = with pkgs; [
    git
    gh # .gitconfig's credential helper shells out to this
    k9s # aliased to `kk`
    kubectl # aliased to `k`
    bat
    htop
    jq

    # --- JavaScript -------------------------------------------------------
    # Volta used to supply node/npm/pnpm/yarn, but it is no longer on PATH in a
    # fresh shell, so `node` was simply missing. These replace it. nodejs ships
    # npm, so npm is not listed separately.
    nodejs_24
    pnpm
    bun
    yarn # Volta provided this too; kept so nothing silently disappears

    # --- Python -----------------------------------------------------------
    # 3.13 rather than pkgs.python3, which is currently 3.14 and too new for a
    # lot of tooling. uv is here because .zshrc sets UV_PYTHON_PREFERENCE=managed
    # and it manages its own interpreters for projects regardless.
    python313
    uv

    # powerlevel10k renders with POWERLEVEL9K_MODE=nerdfont-v3, so it needs a
    # Nerd Font present or the prompt shows tofu boxes. This was installed by
    # hand here (by the `p10k configure` wizard); declaring it means a fresh
    # machine gets a working prompt with no manual step.
    nerd-fonts.meslo-lg
  ];

  # Not on the keep-list, but load-bearing: project devshells load
  # through direnv, and setup.sh removes the imperative ~/.nix-profile copy.
  # Dropping this would break entering any project that uses one.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.tmux = {
    enable = true;
    mouse = true; # was the entire contents of your old ~/.tmux.conf
  };

  ##############################################################################
  # zsh + oh-my-zsh + powerlevel10k
  #
  # home-manager generates ~/.zshrc from this block, so your old hand-edited
  # file is now expressed below. It is kept as ~/.zshrc.hm-bak on first switch.
  ##############################################################################
  programs.zsh = {
    enable = true;

    # These two were custom clones under ~/.oh-my-zsh/custom/plugins. As
    # first-class options they come from nixpkgs and get sourced in the right
    # order (syntax highlighting must be last).
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      # Only OMZ built-ins go here; the two above are handled separately.
      plugins = [ "git" "macos" "extract" ];
    };

    # powerlevel10k is not an OMZ theme in nixpkgs, so it is sourced as a
    # plugin rather than set via oh-my-zsh.theme.
    plugins = [{
      name = "powerlevel10k";
      src = pkgs.zsh-powerlevel10k;
      file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    }];

    initContent = lib.mkMerge [
      # Must be at the very top of .zshrc, before anything can print.
      (lib.mkOrder 500 ''
        typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi

        # Skip OMZ's startup update check and the slow completion-security audit.
        # The nix-managed OMZ lives in the read-only store and cannot self-update.
        zstyle ':omz:update' mode disabled
        ZSH_DISABLE_COMPFIX="true"
      '')

      (lib.mkOrder 1000 ''
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

        export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
        export PATH="$HOME/.local/bin:/Applications/PyCharm.app/Contents/MacOS:$PATH"
        export PATH="$HOME/.nix-profile/bin:$PATH"

        # Guarded: with no JDK 17 present, java_home prints "Unable to locate a
        # Java Runtime" to stderr on every single shell start. The old .zshrc
        # called it unconditionally and did exactly that.
        if /usr/libexec/java_home -v 17 >/dev/null 2>&1; then
          export JAVA_HOME="$(/usr/libexec/java_home -v 17)"
        fi

        # Homebrew (casks are declared in darwin.nix).
        [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

        export UV_PYTHON_PREFERENCE=managed

        # Silence direnv's noisy "export +AR +AS ..." dump on directory entry.
        # The hook itself is installed by programs.direnv above.
        export DIRENV_LOG_FORMAT=""

        alias cdev="cd ~/Develop"
        alias modal="uv run modal"
        alias k="kubectl"
        alias kk="k9s"

        # cmux CLI. The `cmux` binary comes from the cask, symlinked to
        # /opt/homebrew/bin/cmux and picked up by the brew shellenv line above.
        #
        # `cc` shadows /usr/bin/cc (Apple clang), but only on the interactive
        # command line -- make/cargo/nix exec `cc` directly and are unaffected.
        # Use `command cc` or /usr/bin/cc if you want the compiler here.
        alias cc="cmux claude-teams"

        # Opens a new workspace marked remote-SSH and starts the session there.
        # Takes a destination: cssh user@host
        alias cssh="cmux ssh"

        # Machine- and work-specific settings live outside this repo so it can
        # stay publishable: ~/.zsh_secrets for credentials, ~/.zshrc.local for
        # employer-specific env vars, aliases and paths. Neither is tracked.
        [[ -r ~/.zsh_secrets ]] && source ~/.zsh_secrets
        [[ -r ~/.zshrc.local ]] && source ~/.zshrc.local
        [[ -r ~/.safe-chain/scripts/init-posix.sh ]] && source ~/.safe-chain/scripts/init-posix.sh

        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
          source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
        fi
      '')
    ];
  };

  ##############################################################################
  # Dotfiles kept as files (symlinked to the working copy, so still editable).
  ##############################################################################
  home.file.".gitconfig".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/gitconfig";

  # 90KB of generated p10k settings. Out-of-store so `p10k configure` can
  # still rewrite it in place; commit afterwards to sync the change.
  home.file.".p10k.zsh".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/p10k.zsh";

  # cmux itself is a GUI app in /Applications and is NOT packaged in nixpkgs,
  # so only its config is managed here.
  home.file.".config/cmux/cmux.json".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/cmux.json";

  # Referenced by dotfiles/gitconfig as core.excludesfile. Tracking the
  # gitconfig without this left a dangling reference on a fresh machine.
  home.file.".gitignore_global".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/gitignore_global";

  # Whole directory: config references shaders/cursor_warp.glsl, so the shaders
  # have to travel with it or the config is broken on a new machine.
  home.file.".config/ghostty".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/ghostty";

  ##############################################################################
  # Claude Code.
  #
  # Individual files ONLY -- never the whole ~/.claude directory. That also
  # holds credentials, 1.4MB of history.jsonl, 26 project transcripts, session
  # state and shell snapshots, none of which belong in a git repo.
  #
  # The binary is not managed by nix or brew; see setup.sh for why.
  ##############################################################################
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/claude/settings.json";

  # Note: work-book rewrites this file between its marker comments, so it will
  # show up as a repo change whenever that runs. That is expected.
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/claude/CLAUDE.md";

  ##############################################################################
  # claude-code -- intentionally NOT installed.
  #
  # nixpkgs ships 2.1.39; you run 2.1.220 from ~/.local/share/claude/versions.
  # Adding it here would put the older build ahead of yours on PATH, and its
  # self-updater cannot write into the read-only nix store. Uncomment only if
  # you also stop using the self-updating install.
  #
  #   home.packages = [ pkgs.claude-code ];
  ##############################################################################
}
