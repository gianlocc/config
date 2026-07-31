{ pkgs, username, ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";

  ##############################################################################
  # Determinate Nix owns /etc/nix/nix.conf.
  #
  # This is load-bearing, do not flip it. The Exa monorepo's bin/setup_nix.sh
  # appends the `exa-nix-s3-cache-1` trusted key and the
  # `extra-sandbox-paths = /tmp/nix-sccache=/var/nix-sccache` sccache setting to
  # the live nix config. If nix-darwin managed nix.conf it would regenerate the
  # file on every switch and silently drop both, breaking cache hits and slowing
  # Rust builds. With `nix.enable = false`, nix-darwin leaves it alone and
  # setup_nix.sh keeps writing to /etc/nix/nix.custom.conf.
  ##############################################################################
  nix.enable = false;
  determinateNix.enable = true;

  system.stateVersion = 6;
  system.primaryUser = username;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # Lets `sudo darwin-rebuild switch` (which the git hook runs) authenticate
  # with Touch ID instead of stopping to ask for a password mid-`git pull`.
  security.pam.services.sudo_local.touchIdAuth = true;

  environment.shells = [ pkgs.zsh ];

  # macOS settings that are otherwise a pile of `defaults write` you forget.
  # Deliberately conservative -- nothing here changes muscle memory.
  system.defaults = {
    NSGlobalDomain = {
      InitialKeyRepeat = 15; # ~225ms before key repeat kicks in
      KeyRepeat = 2; # fast repeat
      AppleShowAllExtensions = true;
      ApplePressAndHoldEnabled = false; # key repeat instead of accent popup
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
    };

    dock = {
      autohide = true;
      show-recents = false;
      mru-spaces = false; # stop spaces reordering themselves
    };

    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXPreferredViewStyle = "Nlsv"; # list view
      FXEnableExtensionChangeWarning = false;
    };
  };

  ##############################################################################
  # GUI apps -- intentionally OFF.
  #
  # There are ~40 apps already in /Applications, installed by hand, and several
  # of them self-update or ship system extensions (Docker, 1Password, Tailscale,
  # LuLu). Turning this on would have brew try to adopt or reinstall all of them.
  # Enable it deliberately, a few casks at a time, once you want that.
  #
  # homebrew = {
  #   enable = true;
  #   onActivation.cleanup = "none";  # never uninstall anything not listed
  #   casks = [ "ghostty" "rectangle" "cleanshot" ];
  # };
  ##############################################################################
}
