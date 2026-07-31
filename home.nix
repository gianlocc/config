{ pkgs, config, username, ... }:

let
  # Where this repo lives. Dotfiles are symlinked out of the *working copy*
  # (not the nix store) so you can edit ~/.zshrc directly and just commit it.
  repo = "${config.home.homeDirectory}/Develop/configs";
in
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";
  home.stateVersion = "25.05";

  ##############################################################################
  # Global CLI tools.
  #
  # Language toolchains (node, python, rust, go) deliberately do NOT belong
  # here -- those come from the monorepo devshells via direnv, and a global
  # copy would shadow or conflict with the pinned versions there.
  ##############################################################################
  home.packages = with pkgs; [
    gh
    jq
    yq-go
    ripgrep
    fd
    fzf
    bat
    eza
    zoxide # .zshrc evals `zoxide init zsh`; this was missing and erroring
    tree
    htop
    wget
    watch
    difftastic
    kubectl
    k9s # .zshrc aliases kk=k9s
    cachix
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  ##############################################################################
  # Dotfiles.
  #
  # mkOutOfStoreSymlink points ~/.zshrc at the repo file rather than a
  # read-only store path, so editing ~/.zshrc edits the tracked copy. Commit
  # when you feel like it; no rebuild needed for a dotfile tweak.
  ##############################################################################
  home.file.".zshrc".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/zshrc";

  home.file.".gitconfig".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/gitconfig";
}
