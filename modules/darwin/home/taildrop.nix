# Taildrop for the Nix-managed tailscaled, which has none of the Tailscale
# app's Finder integration:
#   - receive: an agent pulls incoming files into ~/Taildrop and posts a
#     notification. Not ~/Downloads: that folder is TCC-protected, and a launchd
#     agent can't answer the permission prompt.
#   - send: a "Send with Taildrop" Quick Action in Finder's right-click menu
#     that asks which online device to send to.
{
  pkgs,
  lib,
  username,
}:

let
  tailscale = "/run/current-system/sw/bin/tailscale";
  inbox = "/Users/${username}/Taildrop";

  receive = pkgs.writeShellScript "taildrop-receive" ''
    mkdir -p ${inbox}
    while true; do
      if ${tailscale} file get --wait --conflict=rename ${inbox}; then
        /usr/bin/osascript -e 'display notification "New files in ~/Taildrop" with title "Taildrop"'
      else
        sleep 30 # tailscaled not up yet, or logged out
      fi
    done
  '';

  send = pkgs.writeShellScript "taildrop-send" ''
    alert() { /usr/bin/osascript -e "display alert \"Taildrop\" message \"$1\"" >/dev/null; }

    for f in "$@"; do
      if [[ -d "$f" ]]; then
        alert "Taildrop sends files, not folders. Compress the folder first."
        exit 1
      fi
    done

    targets=()
    while IFS=$'\t' read -r _ name status; do
      [[ "$status" == *offline* ]] || targets+=("$name")
    done < <(${tailscale} file cp --targets)
    if ((''${#targets[@]} == 0)); then
      alert "No Taildrop targets are online."
      exit 1
    fi

    list=$(printf '"%s",' "''${targets[@]}")
    choice=$(/usr/bin/osascript -e "choose from list {''${list%,}} with title \"Taildrop\" with prompt \"Send $# file(s) to:\"")
    [[ "$choice" == false || -z "$choice" ]] && exit 0

    if err=$(${tailscale} file cp "$@" "$choice:" 2>&1); then
      /usr/bin/osascript -e "display notification \"Sent $# file(s) to $choice\" with title \"Taildrop\""
    else
      alert "Sending to $choice failed: ''${err//\"/}"
      exit 1
    fi
  '';

  service = "Library/Services/Send with Taildrop.workflow/Contents";
in
{
  launchd.agents.taildrop-receive = {
    enable = true;
    config = {
      ProgramArguments = [ "${receive}" ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
    };
  };

  home.file."${service}/Info.plist".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>NSServices</key>
      <array>
        <dict>
          <key>NSMenuItem</key>
          <dict>
            <key>default</key>
            <string>Send with Taildrop</string>
          </dict>
          <key>NSMessage</key>
          <string>runWorkflowAsService</string>
          <key>NSRequiredContext</key>
          <dict>
            <key>NSApplicationIdentifier</key>
            <string>com.apple.finder</string>
          </dict>
          <key>NSSendFileTypes</key>
          <array>
            <string>public.item</string>
          </array>
        </dict>
      </array>
    </dict>
    </plist>
  '';

  # A single "Run Shell Script" action (files passed as arguments), in the
  # format Automator itself writes.
  home.file."${service}/document.wflow".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>AMApplicationBuild</key>
      <string>534</string>
      <key>AMApplicationVersion</key>
      <string>2.10</string>
      <key>AMDocumentVersion</key>
      <string>2</string>
      <key>actions</key>
      <array>
        <dict>
          <key>action</key>
          <dict>
            <key>AMAccepts</key>
            <dict>
              <key>Container</key>
              <string>List</string>
              <key>Optional</key>
              <true/>
              <key>Types</key>
              <array>
                <string>com.apple.cocoa.string</string>
              </array>
            </dict>
            <key>AMActionVersion</key>
            <string>2.0.3</string>
            <key>AMApplication</key>
            <array>
              <string>Automator</string>
            </array>
            <key>AMParameterProperties</key>
            <dict>
              <key>COMMAND_STRING</key>
              <dict/>
              <key>CheckedForUserDefaultShell</key>
              <dict/>
              <key>inputMethod</key>
              <dict/>
              <key>shell</key>
              <dict/>
              <key>source</key>
              <dict/>
            </dict>
            <key>AMProvides</key>
            <dict>
              <key>Container</key>
              <string>List</string>
              <key>Types</key>
              <array>
                <string>com.apple.cocoa.string</string>
              </array>
            </dict>
            <key>ActionBundlePath</key>
            <string>/System/Library/Automator/Run Shell Script.action</string>
            <key>ActionName</key>
            <string>Run Shell Script</string>
            <key>ActionParameters</key>
            <dict>
              <key>COMMAND_STRING</key>
              <string>exec ${send} "$@"</string>
              <key>CheckedForUserDefaultShell</key>
              <true/>
              <key>inputMethod</key>
              <integer>1</integer>
              <key>shell</key>
              <string>/bin/bash</string>
              <key>source</key>
              <string></string>
            </dict>
            <key>BundleIdentifier</key>
            <string>com.apple.RunShellScript</string>
            <key>CFBundleVersion</key>
            <string>2.0.3</string>
            <key>CanShowSelectedItemsWhenRun</key>
            <false/>
            <key>CanShowWhenRun</key>
            <true/>
            <key>Category</key>
            <array>
              <string>AMCategoryUtilities</string>
            </array>
            <key>Class Name</key>
            <string>RunShellScriptAction</string>
            <key>InputUUID</key>
            <string>6F3E2C1A-4B7D-4E8A-9C21-7A5D3B9E1F40</string>
            <key>OutputUUID</key>
            <string>2D8B4F61-9A3C-4C7E-B1D2-5E6F7A8B9C01</string>
            <key>UUID</key>
            <string>A1C2E3F4-5B6D-4E7F-8091-A2B3C4D5E6F7</string>
            <key>UnlocalizedApplications</key>
            <array>
              <string>Automator</string>
            </array>
            <key>arguments</key>
            <dict>
              <key>0</key>
              <dict>
                <key>default value</key>
                <integer>0</integer>
                <key>name</key>
                <string>inputMethod</string>
                <key>required</key>
                <string>0</string>
                <key>type</key>
                <string>0</string>
                <key>uuid</key>
                <string>0</string>
              </dict>
              <key>1</key>
              <dict>
                <key>default value</key>
                <false/>
                <key>name</key>
                <string>CheckedForUserDefaultShell</string>
                <key>required</key>
                <string>0</string>
                <key>type</key>
                <string>0</string>
                <key>uuid</key>
                <string>1</string>
              </dict>
              <key>2</key>
              <dict>
                <key>default value</key>
                <string></string>
                <key>name</key>
                <string>source</string>
                <key>required</key>
                <string>0</string>
                <key>type</key>
                <string>0</string>
                <key>uuid</key>
                <string>2</string>
              </dict>
              <key>3</key>
              <dict>
                <key>default value</key>
                <string></string>
                <key>name</key>
                <string>COMMAND_STRING</string>
                <key>required</key>
                <string>0</string>
                <key>type</key>
                <string>0</string>
                <key>uuid</key>
                <string>3</string>
              </dict>
              <key>4</key>
              <dict>
                <key>default value</key>
                <string>/bin/sh</string>
                <key>name</key>
                <string>shell</string>
                <key>required</key>
                <string>0</string>
                <key>type</key>
                <string>0</string>
                <key>uuid</key>
                <string>4</string>
              </dict>
            </dict>
            <key>conversionLabel</key>
            <integer>0</integer>
            <key>isViewVisible</key>
            <integer>1</integer>
            <key>location</key>
            <string>309.000000:305.000000</string>
            <key>nibPath</key>
            <string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
          </dict>
          <key>isViewVisible</key>
          <integer>1</integer>
        </dict>
      </array>
      <key>connectors</key>
      <dict/>
      <key>workflowMetaData</key>
      <dict>
        <key>applicationBundleIDsByPath</key>
        <dict/>
        <key>applicationPaths</key>
        <array/>
        <key>inputTypeIdentifier</key>
        <string>com.apple.Automator.fileSystemObject</string>
        <key>outputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>presentationMode</key>
        <integer>15</integer>
        <key>processesInput</key>
        <false/>
        <key>serviceInputTypeIdentifier</key>
        <string>com.apple.Automator.fileSystemObject</string>
        <key>serviceOutputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>serviceProcessesInput</key>
        <false/>
        <key>systemImageName</key>
        <string>NSActionTemplate</string>
        <key>useAutomaticInputType</key>
        <false/>
        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.servicesMenu</string>
      </dict>
    </dict>
    </plist>
  '';

  # Make Finder pick up the Quick Action without a logout.
  home.activation.refreshServices = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    /System/Library/CoreServices/pbs -update || true
  '';
}
