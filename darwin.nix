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
  # The module itself does `nix.enable = lib.mkForce false`, so nix-darwin's own
  # nix.conf generation is off and Determinate stays in charge.
  determinateNix.enable = true;

  # The module *does* generate /etc/nix/nix.custom.conf -- the same file
  # setup_nix.sh appends Exa's cache settings to. Anything merely appended there
  # is wiped on the next switch, so it has to be declared here instead. Note
  # this is `determinateNix.customSettings`, NOT `nix.settings`; the latter is
  # silently ignored once the determinate module is in play.
  determinateNix.customSettings = {
    trusted-users = [ "root" "@admin" ];
    extra-substituters = [ "s3://exa-nix-cache?region=us-west-2&priority=50" ];
    extra-trusted-public-keys = [
      "exa-nix-s3-cache-1:mxdfgAYd0CqvvfP9XaOnE1i7lrUACRIIt68iShEGKCA="
    ];
  };

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

  # Typing behaviour only. Dock and Finder are deliberately left alone so this
  # config never rearranges the desktop out from under you -- add
  # `system.defaults.dock` / `.finder` here if you ever want that.
  system.defaults.NSGlobalDomain = {
    InitialKeyRepeat = 15; # ~225ms before key repeat kicks in
    KeyRepeat = 2; # fast repeat
    ApplePressAndHoldEnabled = false; # key repeat instead of the accent popup
    NSAutomaticCapitalizationEnabled = false;
    NSAutomaticDashSubstitutionEnabled = false;
    NSAutomaticQuoteSubstitutionEnabled = false;
    NSAutomaticSpellingCorrectionEnabled = false;
  };

  ##############################################################################
  # GUI apps, via Homebrew casks.
  #
  # Deliberately a short list. There are ~40 apps in /Applications installed by
  # hand, and several self-update or ship system extensions (Docker, 1Password,
  # Tailscale, LuLu); listing those here would have brew fight their updaters.
  # `cleanup = "none"` guarantees nothing not named here is ever uninstalled.
  #
  # cmux is not in nixpkgs, so brew is the only declarative option for it.
  ##############################################################################
  homebrew = {
    enable = true;
    casks = [ "cmux" ];
    onActivation = {
      cleanup = "none"; # never touch apps that aren't listed above
      autoUpdate = false; # don't run `brew update` on every switch
      upgrade = false; # don't silently upgrade casks on every switch
    };
  };
}
