// Native device picker for the "Send with Taildrop" Quick Action.
//   osascript -l JavaScript taildrop-picker.js <file>... -- <name>:<os>...
// Prints the chosen device name, or nothing if cancelled.
ObjC.import("AppKit");

const SYMBOLS = {
  macOS: "desktopcomputer",
  iOS: "iphone",
  android: "candybarphone",
  windows: "pc",
  linux: "server.rack",
};

// The accessibility description must be a string: a JS null bridges to NSNull.
function symbol(name) {
  const image = $.NSImage.imageWithSystemSymbolNameAccessibilityDescription(name, name);
  return image.isNil() ? $.NSImage.imageWithSystemSymbolNameAccessibilityDescription("network", "device") : image;
}

function run(argv) {
  const split = argv.indexOf("--");
  const files = argv.slice(0, split);
  const devices = argv.slice(split + 1).map((entry) => {
    const i = entry.lastIndexOf(":");
    return { name: entry.slice(0, i), os: entry.slice(i + 1) };
  });

  const app = $.NSApplication.sharedApplication;
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);
  app.activateIgnoringOtherApps(true);

  const alert = $.NSAlert.alloc.init;
  const subject =
    files.length === 1
      ? `“${$(files[0]).lastPathComponent.js}”`
      : `${files.length} files`;
  alert.messageText = `Send ${subject} with Taildrop`;
  alert.informativeText = "Choose a device on your tailnet.";
  alert.icon =
    files.length === 1
      ? $.NSWorkspace.sharedWorkspace.iconForFile(files[0])
      : $.NSImage.imageNamed("NSMultipleDocuments");

  const popup = $.NSPopUpButton.alloc.initWithFramePullsDown($.NSMakeRect(0, 0, 260, 28), false);
  for (const device of devices) {
    popup.addItemWithTitle(device.name);
    popup.lastItem.image = symbol(SYMBOLS[device.os] || "network");
  }
  alert.accessoryView = popup;

  alert.addButtonWithTitle("Send");
  alert.addButtonWithTitle("Cancel");
  alert.window.initialFirstResponder = popup;

  if (alert.runModal !== $.NSAlertFirstButtonReturn) return "";
  return popup.titleOfSelectedItem.js;
}
