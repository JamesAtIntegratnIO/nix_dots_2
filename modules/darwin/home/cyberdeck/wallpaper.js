// Sets the desktop picture (argv[0]) on every display. macOS applies it to
// the Space that is showing on each one.
ObjC.import("AppKit");

function run(argv) {
  const url = $.NSURL.fileURLWithPath(argv[0]);
  const screens = $.NSScreen.screens;
  for (let i = 0; i < screens.count; i++) {
    $.NSWorkspace.sharedWorkspace.setDesktopImageURLForScreenOptionsError(
      url,
      screens.objectAtIndex(i),
      $.NSDictionary.dictionary,
      null,
    );
  }
}
