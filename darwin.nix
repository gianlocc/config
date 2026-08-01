{ pkgs, username, ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";

  ##############################################################################
  # This machine runs Determinate Nix, which owns /etc/nix/nix.conf.
  #
  # Load-bearing, do not flip it. With `nix.enable = false` nix-darwin does not
  # generate /etc/nix/nix.conf *or* nix.custom.conf, so whatever else manages
  # those files (Determinate itself, or a work bootstrap script) keeps its
  # settings across every switch.
  #
  # Note this deliberately does NOT use Determinate's nix-darwin module: that
  # module regenerates nix.custom.conf on activation, which would silently drop
  # any setting written there by anything other than this flake.
  ##############################################################################
  nix.enable = false;

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
