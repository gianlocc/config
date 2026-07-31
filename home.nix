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
  # Language toolchains (node, python, rust, go) deliberately do NOT belong
  # here -- those come from the monorepo devshells via direnv, and a global
  # copy would shadow the pinned versions there.
  ##############################################################################
  home.packages = with pkgs; [
    git
    gh # .gitconfig's credential helper shells out to this
    k9s # aliased to `kk`
    kubectl # aliased to `k`
    bat
    htop
    jq

    # powerlevel10k renders with POWERLEVEL9K_MODE=nerdfont-v3, so it needs a
    # Nerd Font present or the prompt shows tofu boxes. This was installed by
    # hand here (by the `p10k configure` wizard); declaring it means a fresh
    # machine gets a working prompt with no manual step.
    nerd-fonts.meslo-lg
  ];

  # Not on the keep-list, but load-bearing: every monorepo devshell loads
  # through direnv, and setup.sh removes the imperative ~/.nix-profile copy.
  # Dropping this would break entering any work repo.
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

        export JAVA_HOME=$(/usr/libexec/java_home -v 17)
        export TILT_NAMESPACE=exan-gianlorenzo
        export UV_PYTHON_PREFERENCE=managed

        # Silence direnv's noisy "export +AR +AS ..." dump on directory entry.
        # The hook itself is installed by programs.direnv above.
        export DIRENV_LOG_FORMAT=""

        alias cdev="cd ~/Develop"
        alias devbox="sh $HOME/Develop/monorepo/personal/gianlo/devbox.sh"
        alias modal="uv run modal"
        alias k="kubectl"
        alias kk="k9s"

        [[ -r ~/.zsh_secrets ]] && source ~/.zsh_secrets
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
