// Installs the screen saver bundle argv[0] into ~/Library/Screen Savers and
// selects it for every display and Space.
//
// macOS has no API or `defaults` key for the choice: it lives next to the
// wallpaper's in WallpaperAgent's store, as the "Idle" half of each entry, and
// the agent only reads the store when it starts. So this rewrites every Idle
// entry and restarts the agent, and does neither when nothing would change.
ObjC.import("Foundation");

const provider = "com.apple.wallpaper.choice.screen-saver";

function run(argv) {
  const fm = $.NSFileManager.defaultManager;
  const home = $.NSHomeDirectory().js;
  const source = argv[0];
  const name = source.split("/").pop().replace(/^[a-z0-9]{32}-/, "");
  const savers = home + "/Library/Screen Savers";
  const target = savers + "/" + name;
  const stamp = savers + "/." + name + ".source";

  // The bundle is copied rather than linked: the saver runs sandboxed and is
  // only handed the bundle it was started from. The store path it came from is
  // recorded beside it (inside would break the signature), which is how a new
  // build is noticed.
  const installed = $.NSString.stringWithContentsOfFileEncodingError(stamp, $.NSUTF8StringEncoding, null);
  let changed = installed.isNil() || installed.js !== source;
  if (changed) {
    fm.createDirectoryAtPathWithIntermediateDirectoriesAttributesError(savers, true, $(), null);
    fm.removeItemAtPathError(target, null);
    // ditto drops the store's read-only modes, so the next copy can replace it.
    const copy = $.NSTask.launchedTaskWithLaunchPathArguments("/usr/bin/ditto", ["--noqtn", source, target]);
    copy.waitUntilExit;
    $.NSTask.launchedTaskWithLaunchPathArguments("/bin/chmod", ["-R", "u+w", target]).waitUntilExit;
    // The build can only sign the binary; the system wants the bundle sealed.
    $.NSTask.launchedTaskWithLaunchPathArguments("/usr/bin/codesign", ["-f", "-s", "-", target]).waitUntilExit;
    $(source).writeToFileAtomicallyEncodingError(stamp, true, $.NSUTF8StringEncoding, null);
  }

  const index = home + "/Library/Application Support/com.apple.wallpaper/Store/Index.plist";
  const data = $.NSData.dataWithContentsOfFile(index);
  if (data.isNil()) {
    console.log("cyberdeck: no wallpaper store yet, leaving the screen saver alone");
    return;
  }
  const store = $.NSPropertyListSerialization.propertyListWithDataOptionsFormatError(
    data,
    $.NSPropertyListMutableContainers,
    null,
    null,
  );

  const url = $.NSURL.fileURLWithPathIsDirectory(target, true).absoluteString;
  const configuration = $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError(
    $({ module: { relative: url } }),
    $.NSPropertyListBinaryFormat_v1_0,
    0,
    null,
  );

  // Idle entries sit at different depths (per display, per Space, per display
  // within a Space), so walk the whole store.
  const visit = (node) => {
    if (!node.isKindOfClass($.NSDictionary)) return;
    const keys = node.allKeys;
    for (let i = 0; i < keys.count; i++) {
      const key = keys.objectAtIndex(i);
      const value = node.objectForKey(key);
      if (key.js !== "Idle") {
        visit(value);
        continue;
      }
      const content = value.objectForKey("Content");
      const first = content.objectForKey("Choices").firstObject;
      if (!first.isNil() && first.objectForKey("Provider").js === provider && first.objectForKey("Configuration").isEqual(configuration)) continue;
      content.setObjectForKey($([{ Provider: provider, Files: [], Configuration: configuration }]), "Choices");
      value.setObjectForKey($.NSDate.date, "LastSet");
      changed = true;
    }
  };
  visit(store);
  if (!changed) return;

  $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError(
    store,
    $.NSPropertyListBinaryFormat_v1_0,
    0,
    null,
  ).writeToFileAtomically(index, true);
  $.NSTask.launchedTaskWithLaunchPathArguments("/usr/bin/killall", ["WallpaperAgent"]).waitUntilExit;
}
