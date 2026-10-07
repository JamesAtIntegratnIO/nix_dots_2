# The VS Code color theme, generated from the palette and packaged twice:
# `extension` is the unpacked tree Home Manager's programs.vscode links in, and
# `vsix` is the same tree as an installable archive, for a VS Code that Nix
# does not manage (the Mac's). ../../../home/cyberdeck.nix installs both.
{ pkgs, palette }:

let
  publisher = "integratn";
  name = "cyberdeck-theme";
  version = "1.0.0";
  label = "Cyberdeck";

  c = color: "#${palette.${color}}";
  # With two hex digits of alpha.
  a = color: alpha: "#${palette.${color}}${alpha}";

  token = scope: settings: { inherit scope settings; };
  fg = color: { foreground = c color; };

  theme = {
    name = label;
    type = "dark";
    semanticHighlighting = true;

    colors = {
      focusBorder = a "cyan" "99";
      foreground = c "text";
      disabledForeground = c "overlay";
      descriptionForeground = c "subtext";
      errorForeground = c "red";
      "icon.foreground" = c "subtext";
      "selection.background" = a "cyan" "55";
      "widget.shadow" = a "void" "cc";
      "sash.hoverBorder" = c "cyan";
      "textLink.foreground" = c "cyan";
      "textLink.activeForeground" = c "cyanBright";
      "textPreformat.foreground" = c "green";
      "textBlockQuote.background" = c "mantle";
      "textBlockQuote.border" = c "overlay";
      "textCodeBlock.background" = c "mantle";

      "editor.background" = c "base";
      "editor.foreground" = c "text";
      "editorCursor.foreground" = c "green";
      "editor.lineHighlightBackground" = c "mantle";
      "editor.selectionBackground" = a "cyan" "40";
      "editor.inactiveSelectionBackground" = a "cyan" "20";
      "editor.selectionHighlightBackground" = a "cyan" "25";
      "editor.wordHighlightBackground" = a "blue" "40";
      "editor.wordHighlightStrongBackground" = a "magenta" "40";
      "editor.findMatchBackground" = a "magenta" "70";
      "editor.findMatchHighlightBackground" = a "amber" "45";
      "editor.hoverHighlightBackground" = a "cyan" "20";
      "editorLineNumber.foreground" = c "overlay";
      "editorLineNumber.activeForeground" = c "amber";
      "editorIndentGuide.background1" = c "surface";
      "editorIndentGuide.activeBackground1" = c "overlay";
      "editorWhitespace.foreground" = c "surface";
      "editorRuler.foreground" = c "surface";
      "editorBracketMatch.background" = a "cyan" "25";
      "editorBracketMatch.border" = c "cyan";
      "editorBracketHighlight.foreground1" = c "cyan";
      "editorBracketHighlight.foreground2" = c "magenta";
      "editorBracketHighlight.foreground3" = c "amber";
      "editorBracketHighlight.foreground4" = c "green";
      "editorBracketHighlight.foreground5" = c "purple";
      "editorBracketHighlight.foreground6" = c "blue";
      "editorError.foreground" = c "red";
      "editorWarning.foreground" = c "amber";
      "editorInfo.foreground" = c "blue";
      "editorHint.foreground" = c "cyan";
      "editorGutter.addedBackground" = c "green";
      "editorGutter.modifiedBackground" = c "amber";
      "editorGutter.deletedBackground" = c "red";
      "editorCodeLens.foreground" = c "overlay";
      "editorInlayHint.foreground" = c "subtext";
      "editorInlayHint.background" = c "mantle";
      "editorGhostText.foreground" = c "overlay";
      "editorOverviewRuler.border" = c "base";
      "editorLink.activeForeground" = c "cyanBright";

      "editorWidget.background" = c "mantle";
      "editorWidget.border" = c "surface";
      "editorSuggestWidget.background" = c "mantle";
      "editorSuggestWidget.border" = c "surface";
      "editorSuggestWidget.selectedBackground" = c "surface";
      "editorSuggestWidget.highlightForeground" = c "cyan";
      "editorSuggestWidget.focusHighlightForeground" = c "cyanBright";
      "editorHoverWidget.background" = c "mantle";
      "editorHoverWidget.border" = c "surface";
      "editorGroup.border" = c "surface";
      "editorGroupHeader.tabsBackground" = c "void";
      "editorGroupHeader.noTabsBackground" = c "void";
      "diffEditor.insertedTextBackground" = a "green" "22";
      "diffEditor.removedTextBackground" = a "red" "28";
      "diffEditor.insertedLineBackground" = a "green" "12";
      "diffEditor.removedLineBackground" = a "red" "16";
      "peekView.border" = c "cyan";
      "peekViewEditor.background" = c "mantle";
      "peekViewResult.background" = c "mantle";
      "peekViewTitle.background" = c "void";
      "peekViewTitleLabel.foreground" = c "cyan";
      "peekViewEditor.matchHighlightBackground" = a "amber" "45";
      "peekViewResult.matchHighlightBackground" = a "amber" "45";
      "peekViewResult.selectionBackground" = c "surface";

      "tab.activeBackground" = c "base";
      "tab.activeForeground" = c "bright";
      "tab.activeBorderTop" = c "cyan";
      "tab.inactiveBackground" = c "void";
      "tab.inactiveForeground" = c "subtext";
      "tab.hoverBackground" = c "mantle";
      "tab.border" = c "void";
      "tab.unfocusedActiveBorderTop" = c "overlay";

      "titleBar.activeBackground" = c "void";
      "titleBar.activeForeground" = c "text";
      "titleBar.inactiveBackground" = c "void";
      "titleBar.inactiveForeground" = c "overlay";
      "titleBar.border" = c "surface";
      "commandCenter.background" = c "mantle";
      "commandCenter.border" = c "surface";
      "commandCenter.foreground" = c "subtext";
      "menu.background" = c "mantle";
      "menu.foreground" = c "text";
      "menu.selectionBackground" = c "surface";
      "menu.selectionForeground" = c "bright";
      "menu.separatorBackground" = c "surface";
      "menubar.selectionBackground" = c "surface";

      "activityBar.background" = c "void";
      "activityBar.foreground" = c "cyan";
      "activityBar.inactiveForeground" = c "overlay";
      "activityBar.activeBorder" = c "cyan";
      "activityBar.border" = c "surface";
      "activityBarBadge.background" = c "magenta";
      "activityBarBadge.foreground" = c "void";

      "sideBar.background" = c "void";
      "sideBar.foreground" = c "text";
      "sideBar.border" = c "surface";
      "sideBarTitle.foreground" = c "subtext";
      "sideBarSectionHeader.background" = c "void";
      "sideBarSectionHeader.foreground" = c "cyan";
      "sideBarSectionHeader.border" = c "surface";

      "list.activeSelectionBackground" = c "surface";
      "list.activeSelectionForeground" = c "bright";
      "list.inactiveSelectionBackground" = c "mantle";
      "list.hoverBackground" = c "mantle";
      "list.focusBackground" = c "surface";
      "list.focusOutline" = a "cyan" "99";
      "list.highlightForeground" = c "cyan";
      "list.errorForeground" = c "red";
      "list.warningForeground" = c "amber";
      "tree.indentGuidesStroke" = c "surface";

      "statusBar.background" = c "void";
      "statusBar.foreground" = c "subtext";
      "statusBar.border" = c "surface";
      "statusBar.noFolderBackground" = c "void";
      "statusBar.debuggingBackground" = c "amber";
      "statusBar.debuggingForeground" = c "void";
      "statusBarItem.remoteBackground" = c "cyan";
      "statusBarItem.remoteForeground" = c "void";
      "statusBarItem.hoverBackground" = c "surface";
      "statusBarItem.errorBackground" = c "red";
      "statusBarItem.errorForeground" = c "void";
      "statusBarItem.warningBackground" = c "amber";
      "statusBarItem.warningForeground" = c "void";

      "panel.background" = c "base";
      "panel.border" = c "surface";
      "panelTitle.activeForeground" = c "cyan";
      "panelTitle.activeBorder" = c "cyan";
      "panelTitle.inactiveForeground" = c "subtext";

      "input.background" = c "mantle";
      "input.foreground" = c "text";
      "input.border" = c "surface";
      "input.placeholderForeground" = c "overlay";
      "inputOption.activeBackground" = a "cyan" "40";
      "inputOption.activeBorder" = c "cyan";
      "inputValidation.errorBackground" = c "mantle";
      "inputValidation.errorBorder" = c "red";
      "inputValidation.warningBackground" = c "mantle";
      "inputValidation.warningBorder" = c "amber";
      "inputValidation.infoBackground" = c "mantle";
      "inputValidation.infoBorder" = c "blue";
      "dropdown.background" = c "mantle";
      "dropdown.foreground" = c "text";
      "dropdown.border" = c "surface";
      "checkbox.background" = c "mantle";
      "checkbox.border" = c "overlay";
      "button.background" = c "cyan";
      "button.foreground" = c "void";
      "button.hoverBackground" = c "cyanBright";
      "button.secondaryBackground" = c "surface";
      "button.secondaryForeground" = c "text";
      "button.secondaryHoverBackground" = c "overlay";
      "badge.background" = c "magenta";
      "badge.foreground" = c "void";
      "progressBar.background" = c "cyan";
      "scrollbar.shadow" = a "void" "00";
      "scrollbarSlider.background" = a "overlay" "55";
      "scrollbarSlider.hoverBackground" = a "overlay" "99";
      "scrollbarSlider.activeBackground" = a "cyan" "77";
      "minimap.findMatchHighlight" = c "amber";
      "minimap.selectionHighlight" = c "cyan";
      "minimapSlider.background" = a "overlay" "33";

      "quickInput.background" = c "mantle";
      "quickInput.foreground" = c "text";
      "quickInputTitle.background" = c "void";
      "quickInputList.focusBackground" = c "surface";
      "quickInputList.focusForeground" = c "bright";
      "pickerGroup.foreground" = c "cyan";
      "pickerGroup.border" = c "surface";
      "notifications.background" = c "mantle";
      "notifications.foreground" = c "text";
      "notifications.border" = c "surface";
      "notificationCenterHeader.background" = c "void";
      "notificationLink.foreground" = c "cyan";
      "notificationsErrorIcon.foreground" = c "red";
      "notificationsWarningIcon.foreground" = c "amber";
      "notificationsInfoIcon.foreground" = c "blue";
      "breadcrumb.foreground" = c "subtext";
      "breadcrumb.focusForeground" = c "text";
      "breadcrumb.activeSelectionForeground" = c "cyan";
      "breadcrumbPicker.background" = c "mantle";
      "settings.headerForeground" = c "cyan";
      "settings.modifiedItemIndicator" = c "amber";
      "keybindingLabel.foreground" = c "text";
      "keybindingLabel.background" = c "surface";
      "keybindingLabel.border" = c "overlay";
      "welcomePage.tileBackground" = c "mantle";

      "gitDecoration.addedResourceForeground" = c "green";
      "gitDecoration.modifiedResourceForeground" = c "amber";
      "gitDecoration.deletedResourceForeground" = c "red";
      "gitDecoration.renamedResourceForeground" = c "cyan";
      "gitDecoration.untrackedResourceForeground" = c "greenBright";
      "gitDecoration.ignoredResourceForeground" = c "overlay";
      "gitDecoration.conflictingResourceForeground" = c "magenta";
      "gitDecoration.stageModifiedResourceForeground" = c "amberBright";

      "debugToolBar.background" = c "mantle";
      "debugIcon.breakpointForeground" = c "red";
      "editor.stackFrameHighlightBackground" = a "amber" "30";
      "testing.iconPassed" = c "green";
      "testing.iconFailed" = c "red";
      "testing.iconQueued" = c "amber";
      "charts.red" = c "red";
      "charts.green" = c "green";
      "charts.yellow" = c "amber";
      "charts.blue" = c "blue";
      "charts.purple" = c "purple";
      "charts.orange" = c "amberBright";

      # The integrated terminal gets the same 16 slots as every other terminal.
      "terminal.background" = c "base";
      "terminal.foreground" = c "text";
      "terminal.selectionBackground" = a "cyan" "40";
      "terminalCursor.foreground" = c "green";
      "terminalCursor.background" = c "void";
      "terminal.border" = c "surface";
    }
    // builtins.listToAttrs (
      pkgs.lib.imap0 (i: hex: {
        name = "terminal.ansi${
          builtins.elemAt [
            "Black"
            "Red"
            "Green"
            "Yellow"
            "Blue"
            "Magenta"
            "Cyan"
            "White"
            "BrightBlack"
            "BrightRed"
            "BrightGreen"
            "BrightYellow"
            "BrightBlue"
            "BrightMagenta"
            "BrightCyan"
            "BrightWhite"
          ] i
        }";
        value = "#${hex}";
      }) palette.ansi
    );

    # The same assignments as the Neovim scheme (./nvim-colors.lua): keywords
    # magenta, functions cyan, strings green, constants amber, types blue.
    tokenColors = [
      (token [ "comment" "punctuation.definition.comment" ] (fg "subtext" // { fontStyle = "italic"; }))
      (token [ "string" "markup.inline.raw" "markup.fenced_code" ] (fg "green"))
      (token [ "constant.character.escape" "string.regexp" ] (fg "cyanBright"))
      (token [ "constant" "constant.numeric" "constant.language" "support.constant" ] (fg "amber"))
      (token [ "keyword" "storage" "storage.type" "storage.modifier" "keyword.control" ] (fg "magenta"))
      (token [ "keyword.operator" "punctuation.accessor" ] (fg "cyanBright"))
      (token [ "entity.name.function" "support.function" "meta.function-call" ] (fg "cyan"))
      (token [
        "entity.name.type"
        "entity.name.class"
        "support.type"
        "support.class"
        "entity.other.inherited-class"
      ] (fg "blueBright"))
      (token [ "variable" "meta.definition.variable" ] (fg "text"))
      (token [ "variable.parameter" ] (fg "bright"))
      (token [ "variable.language" "entity.name.namespace" "entity.name.module" ] (fg "purple"))
      (token [
        "variable.other.property"
        "variable.other.object.property"
        "meta.object-literal.key"
        "support.type.property-name"
        "entity.name.tag.yaml"
      ] (fg "blueBright"))
      (token [ "entity.name.tag" ] (fg "cyan"))
      (token [ "entity.other.attribute-name" ] (fg "amber"))
      (token [ "meta.preprocessor" "keyword.control.import" "keyword.control.directive" ] (fg "purple"))
      (token [ "punctuation" "meta.brace" ] (fg "subtext"))
      (token [ "invalid" ] (fg "red"))
      (token [ "markup.heading" "entity.name.section" ] (fg "cyan" // { fontStyle = "bold"; }))
      (token [ "markup.bold" ] (fg "bright" // { fontStyle = "bold"; }))
      (token [ "markup.italic" ] { fontStyle = "italic"; })
      (token [ "markup.underline.link" "string.other.link" ] (fg "blue"))
      (token [ "markup.quote" ] (fg "subtext"))
      (token [ "markup.inserted" ] (fg "green"))
      (token [ "markup.changed" ] (fg "amber"))
      (token [ "markup.deleted" ] (fg "red"))
    ];

    semanticTokenColors = {
      parameter = c "bright";
      property = c "blueBright";
      namespace = c "purple";
      "variable.defaultLibrary" = c "purple";
      "variable.readonly" = c "amber";
      enumMember = c "amber";
    };
  };

  package = {
    inherit name publisher version;
    displayName = label;
    description = "The cyberdeck palette, generated from palette.nix.";
    engines.vscode = "^1.70.0";
    categories = [ "Themes" ];
    contributes.themes = [
      {
        inherit label;
        uiTheme = "vs-dark";
        path = "./themes/cyberdeck-color-theme.json";
      }
    ];
  };

  tree = pkgs.runCommand "${name}-${version}-src" { } ''
    mkdir -p $out/themes
    cp ${pkgs.writeText "package.json" (builtins.toJSON package)} $out/package.json
    cp ${pkgs.writeText "theme.json" (builtins.toJSON theme)} $out/themes/cyberdeck-color-theme.json
  '';

  manifest = pkgs.writeText "extension.vsixmanifest" ''
    <?xml version="1.0" encoding="utf-8"?>
    <PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011">
      <Metadata>
        <Identity Language="en-US" Id="${name}" Version="${version}" Publisher="${publisher}"/>
        <DisplayName>${label}</DisplayName>
        <Description xml:space="preserve">${package.description}</Description>
        <Categories>Themes</Categories>
        <Properties>
          <Property Id="Microsoft.VisualStudio.Code.Engine" Value="${package.engines.vscode}"/>
        </Properties>
      </Metadata>
      <Installation>
        <InstallationTarget Id="Microsoft.VisualStudio.Code"/>
      </Installation>
      <Dependencies/>
      <Assets>
        <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>
      </Assets>
    </PackageManifest>
  '';

  contentTypes = pkgs.writeText "content-types.xml" ''
    <?xml version="1.0" encoding="utf-8"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension=".json" ContentType="application/json"/>
      <Default Extension=".vsixmanifest" ContentType="text/xml"/>
    </Types>
  '';
in
{
  inherit label;

  extension =
    pkgs.runCommand "vscode-extension-${publisher}-${name}-${version}"
      {
        inherit version;
        passthru = {
          vscodeExtPublisher = publisher;
          vscodeExtName = name;
          vscodeExtUniqueId = "${publisher}.${name}";
        };
      }
      ''
        mkdir -p $out/share/vscode/extensions
        cp -r ${tree} $out/share/vscode/extensions/${publisher}.${name}
      '';

  vsix =
    pkgs.runCommand "${publisher}.${name}-${version}.vsix" { nativeBuildInputs = [ pkgs.zip ]; }
      ''
        cp -r ${tree} extension
        cp ${manifest} extension.vsixmanifest
        cp ${contentTypes} '[Content_Types].xml'
        chmod -R u+w extension
        zip -qr $out extension extension.vsixmanifest '[Content_Types].xml'
      '';
}
