# Firefox for a 640x480 panel: compact density, no bookmarks bar, dark, and the
# "System" theme so it inherits the palette-recolored adw-gtk3 (cyan accent).
# Policies also strip the new-tab clutter that wastes the little space there is.
{ ... }:

{
  programs.firefox = {
    enable = true; # browser (Pineapple web UI etc.)

    preferences = {
      "browser.compactmode.show" = true;
      "browser.uidensity" = 1; # compact
      "browser.toolbars.bookmarks.visibility" = "never";
      "extensions.activeThemeID" = "default-theme@mozilla.org"; # follow GTK
      "ui.systemUsesDarkTheme" = 1;
      "layout.css.prefers-color-scheme.content-override" = 0; # dark sites
      "browser.tabs.inTitlebar" = 0; # Sway draws no titlebar anyway
      "sidebar.revamp" = false;
      # Touch: kinetic scrolling and pinch-zoom on the GT911.
      "apz.gtk.kinetic_scroll.enabled" = true;
      "browser.gesture.pinch.in" = "cmd_fullZoomReduce";
      "browser.gesture.pinch.out" = "cmd_fullZoomEnlarge";
      # Quieter new tab.
      "browser.newtabpage.activity-stream.showSponsored" = false;
      "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
      "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
    };
    preferencesStatus = "default"; # user can still change these in about:config

    policies = {
      DisplayBookmarksToolbar = "never";
      DisablePocket = true;
      DisableFirefoxStudies = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = true;
      OfferToSaveLogins = false; # 1Password handles this
      FirefoxHome = {
        Search = true;
        TopSites = false;
        SponsoredTopSites = false;
        Highlights = false;
        Pocket = false;
        SponsoredPocket = false;
        Snippets = false;
        Locked = false;
      };
      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        SkipOnboarding = true;
        MoreFromMozilla = false;
        Locked = false;
      };
    };
  };
}
