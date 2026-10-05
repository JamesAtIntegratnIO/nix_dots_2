// Sets the desktop picture on every display to one of the images in argv[1..],
// moving to the next every argv[0] seconds. The image is picked from the
// clock, so there is nothing to remember between runs and every display
// agrees. macOS applies it to the Space that is showing on each one.
ObjC.import("AppKit");

function run(argv) {
  const [seconds, ...images] = argv;
  const turn = Math.floor(Date.now() / 1000 / Number(seconds));
  const url = $.NSURL.fileURLWithPath(images[turn % images.length]);
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
