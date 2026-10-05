// Writes the Terminal.app profile described by a JSON spec (argv[0], built in
// ./default.nix) into com.apple.Terminal and makes it the default.
//
// A new profile starts as a copy of the current default, and an existing one
// is updated in place, so settings the spec does not mention (window size,
// Option-as-Meta, bell) keep whatever was chosen in Terminal's settings.
ObjC.import("AppKit");

function color(hex, alpha) {
  const ch = (i) => parseInt(hex.substr(i, 2), 16) / 255;
  const c = $.NSColor.colorWithSRGBRedGreenBlueAlpha(ch(0), ch(2), ch(4), alpha);
  return $.NSKeyedArchiver.archivedDataWithRootObjectRequiringSecureCodingError(c, false, null);
}

function run(argv) {
  const spec = JSON.parse($.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null).js);
  const defaults = $.NSUserDefaults.alloc.initWithSuiteName("com.apple.Terminal");

  const stored = defaults.dictionaryForKey("Window Settings");
  const profiles = stored.isNil() ? $.NSMutableDictionary.dictionary : $.NSMutableDictionary.dictionaryWithDictionary(stored);
  let base = profiles.objectForKey(spec.name);
  if (base.isNil()) {
    const current = defaults.stringForKey("Default Window Settings");
    if (!current.isNil()) base = profiles.objectForKey(current);
  }
  const profile = base.isNil() ? $.NSMutableDictionary.dictionary : $.NSMutableDictionary.dictionaryWithDictionary(base);

  const set = (key, value) => profile.setObjectForKey(value, key);
  set("name", spec.name);
  set("type", "Window Settings");

  const slots = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"];
  spec.ansi.forEach((hex, i) => set("ANSI" + (i < 8 ? "" : "Bright") + slots[i % 8] + "Color", color(hex, 1)));
  set("BackgroundColor", color(spec.background, spec.opacity));
  set("TextColor", color(spec.text, 1));
  set("TextBoldColor", color(spec.bold, 1));
  set("CursorColor", color(spec.cursor, 1));
  set("SelectionColor", color(spec.selection, 1));
  set("CursorType", $.NSNumber.numberWithInt(0)); // block
  set("CursorBlink", true);

  // The font arrives in the same rebuild, and the font server can lag behind
  // it; the next activation picks it up.
  const font = $.NSFontManager.sharedFontManager.fontWithFamilyTraitsWeightSize(spec.font, 0, 5, spec.fontSize);
  if (font.isNil()) {
    console.log("cyberdeck: font '" + spec.font + "' not available yet, leaving the profile's font alone");
  } else {
    set("Font", $.NSKeyedArchiver.archivedDataWithRootObjectRequiringSecureCodingError(font, false, null));
  }

  profiles.setObjectForKey(profile, spec.name);
  defaults.setObjectForKey(profiles, "Window Settings");
  defaults.setObjectForKey(spec.name, "Default Window Settings");
  defaults.setObjectForKey(spec.name, "Startup Window Settings");
  defaults.synchronize;
}
