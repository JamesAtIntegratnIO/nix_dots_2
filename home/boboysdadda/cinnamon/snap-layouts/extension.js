// macOS / Windows 11 style window tiling on top of Muffin's edge tiling:
//
// - Drag a window to the top edge of a monitor and a strip of layouts drops
//   down; release over a zone to tile the window there.
// - The window menu (right-click the titlebar, Alt+Space, or Super+Z) gets
//   the same layouts as clickable thumbnails, plus Fill, Center, Restore and
//   Full Screen (which fullscreen-spaces@local moves to its own workspace).
//
// Halves and quarters use Muffin's own tiles (the same ones Super+arrows and
// edge drags produce), so dragging the window away restores its old size and
// tiled neighbours resize together. Thirds have no Muffin tile mode, so those
// are a plain move/resize.

const GLib = imports.gi.GLib;
const Meta = imports.gi.Meta;
const St = imports.gi.St;
const Main = imports.ui.main;
const PopupMenu = imports.ui.popupMenu;
const WindowMenu = imports.ui.windowMenu;

// Zones are [x, y, width, height] as fractions of the monitor's work area.
const LAYOUTS = [
    [[0, 0, 1 / 2, 1], [1 / 2, 0, 1 / 2, 1]],
    [[0, 0, 1, 1 / 2], [0, 1 / 2, 1, 1 / 2]],
    [[0, 0, 1 / 3, 1], [1 / 3, 0, 1 / 3, 1], [2 / 3, 0, 1 / 3, 1]],
    [[0, 0, 2 / 3, 1], [2 / 3, 0, 1 / 3, 1]],
    [[0, 0, 1 / 3, 1], [1 / 3, 0, 2 / 3, 1]],
    [[0, 0, 1 / 2, 1], [1 / 2, 0, 1 / 2, 1 / 2], [1 / 2, 1 / 2, 1 / 2, 1 / 2]],
    [[0, 0, 1 / 2, 1 / 2], [1 / 2, 0, 1 / 2, 1 / 2], [0, 1 / 2, 1 / 2, 1 / 2], [1 / 2, 1 / 2, 1 / 2, 1 / 2]],
];

const THUMB_WIDTH = 80;
const THUMB_HEIGHT = 50; // the laptop's 16:10
const THUMB_GAP = 3;
const EDGE = 4; // px from the top of the work area that opens the picker
const POLL_MS = 30;
const HOTKEY = 'snap-layouts-menu';

let grabBeginId = 0;
let grabEndId = 0;
let drag = null;
let origBuildMenu = null;

// --- Tiling -------------------------------------------------------------------

const near = (a, b) => Math.abs(a - b) < 0.01;
const zoneIs = (z, x, y, w, h) => near(z[0], x) && near(z[1], y) && near(z[2], w) && near(z[3], h);

// Muffin push-tile steps (from untiled) that land on this zone, or null.
function nativeSteps(z) {
    const M = Meta.MotionDirection;
    const table = [
        [[0, 0, 0.5, 1], [M.LEFT]],
        [[0.5, 0, 0.5, 1], [M.RIGHT]],
        [[0, 0, 1, 0.5], [M.UP]],
        [[0, 0.5, 1, 0.5], [M.DOWN]],
        [[0, 0, 0.5, 0.5], [M.LEFT, M.UP]],
        [[0.5, 0, 0.5, 0.5], [M.RIGHT, M.UP]],
        [[0, 0.5, 0.5, 0.5], [M.LEFT, M.DOWN]],
        [[0.5, 0.5, 0.5, 0.5], [M.RIGHT, M.DOWN]],
    ];
    for (const [zone, steps] of table) {
        if (zoneIs(z, ...zone))
            return steps;
    }
    return null;
}

function zoneRect(area, z) {
    // Round the edges, not the sizes, so neighbouring zones meet exactly.
    const x0 = Math.round(area.x + z[0] * area.width);
    const y0 = Math.round(area.y + z[1] * area.height);
    const x1 = Math.round(area.x + (z[0] + z[2]) * area.width);
    const y1 = Math.round(area.y + (z[1] + z[3]) * area.height);
    return { x: x0, y: y0, width: x1 - x0, height: y1 - y0 };
}

function untile(window) {
    if (window.is_fullscreen())
        window.unmake_fullscreen();
    // Muffin's tiles count as vertically maximized, so this untiles too.
    if (window.get_maximized())
        window.unmaximize(Meta.MaximizeFlags.BOTH);
}

function tile(window, z, monitor = window.get_monitor()) {
    if (!window.allows_resize())
        return;
    if (window.get_monitor() !== monitor)
        window.move_to_monitor(monitor);
    untile(window);
    const steps = nativeSteps(z);
    if (steps) {
        for (const step of steps)
            global.display.push_tile(window, step);
        return;
    }
    const r = zoneRect(window.get_work_area_for_monitor(monitor), z);
    window.move_resize_frame(true, r.x, r.y, r.width, r.height);
}

function center(window) {
    untile(window);
    const area = window.get_work_area_current_monitor();
    const frame = window.get_frame_rect();
    window.move_frame(true,
        area.x + Math.round((area.width - frame.width) / 2),
        area.y + Math.round((area.height - frame.height) / 2));
}

// --- Layout thumbnails --------------------------------------------------------

// One thumbnail per layout; every zone is a button. onPick(zone) runs on click.
function buildPicker(onPick) {
    const box = new St.BoxLayout({ style_class: 'snap-picker' });
    const cells = [];
    for (const layout of LAYOUTS) {
        const thumb = new St.Widget({
            style_class: 'snap-layout',
            width: THUMB_WIDTH,
            height: THUMB_HEIGHT,
        });
        for (const z of layout) {
            const x0 = Math.round(z[0] * THUMB_WIDTH), x1 = Math.round((z[0] + z[2]) * THUMB_WIDTH);
            const y0 = Math.round(z[1] * THUMB_HEIGHT), y1 = Math.round((z[1] + z[3]) * THUMB_HEIGHT);
            const cell = new St.Button({
                style_class: 'snap-cell',
                reactive: true,
                can_focus: true,
                track_hover: true,
                x: x0 + THUMB_GAP / 2,
                y: y0 + THUMB_GAP / 2,
                width: x1 - x0 - THUMB_GAP,
                height: y1 - y0 - THUMB_GAP,
            });
            cell.connect('clicked', () => onPick(z));
            thumb.add_actor(cell);
            cells.push({ actor: cell, zone: z });
        }
        box.add_actor(thumb);
    }
    return { actor: box, cells };
}

// --- Drag to the top edge -----------------------------------------------------

function contains(actor, x, y, margin = 0) {
    const [ax, ay] = actor.get_transformed_position();
    const [aw, ah] = actor.get_transformed_size();
    return x >= ax - margin && x < ax + aw + margin && y >= ay - margin && y < ay + ah + margin;
}

function dragTick() {
    const d = drag;
    const [x, y] = global.get_pointer();
    const monitor = global.display.get_monitor_index_for_rect(
        new Meta.Rectangle({ x, y, width: 1, height: 1 }));
    const area = d.window.get_work_area_for_monitor(monitor);
    const atEdge = y <= area.y + EDGE && x >= area.x && x < area.x + area.width;

    if (atEdge && (!d.picker.actor.visible || d.monitor !== monitor)) {
        d.monitor = monitor;
        const [, natWidth] = d.picker.actor.get_preferred_width(-1);
        d.picker.actor.set_position(
            Math.round(area.x + (area.width - natWidth) / 2), area.y + 8);
        d.picker.actor.show();
    } else if (d.picker.actor.visible && !atEdge && !contains(d.picker.actor, x, y, 24)) {
        d.picker.actor.hide();
    }

    let hot = null;
    if (d.picker.actor.visible)
        hot = d.picker.cells.find(c => contains(c.actor, x, y)) || null;
    if (hot !== d.hot) {
        if (d.hot)
            d.hot.actor.remove_style_pseudo_class('hover');
        d.hot = hot;
        if (hot) {
            hot.actor.add_style_pseudo_class('hover');
            const r = zoneRect(area, hot.zone);
            d.preview.set_position(r.x, r.y);
            d.preview.set_size(r.width, r.height);
            d.preview.show();
        } else {
            d.preview.hide();
        }
    }
    return GLib.SOURCE_CONTINUE;
}

function endDrag() {
    if (!drag)
        return null;
    const d = drag;
    drag = null;
    GLib.source_remove(d.timer);
    d.picker.actor.destroy();
    d.preview.destroy();
    return d;
}

function onGrabBegin(_display, window, op) {
    endDrag();
    if (op !== Meta.GrabOp.MOVING || !window ||
        window.get_window_type() !== Meta.WindowType.NORMAL || !window.allows_resize())
        return;

    const picker = buildPicker(() => {});
    picker.actor.hide();
    Main.uiGroup.add_actor(picker.actor);

    const preview = new St.Widget({ style_class: 'snap-preview', visible: false });
    global.window_group.add_actor(preview);
    const windowActor = window.get_compositor_private();
    if (windowActor && windowActor.get_parent() === global.window_group)
        global.window_group.set_child_below_sibling(preview, windowActor);

    drag = { window, picker, preview, hot: null, monitor: -1, timer: 0 };
    drag.timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, POLL_MS, dragTick);
}

function onGrabEnd(_display, window) {
    const d = endDrag();
    if (!d || !d.hot || d.window !== window)
        return;
    const { zone } = d.hot;
    const monitor = d.monitor;
    // Let Muffin finish the move it was doing before re-placing the window.
    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
        if (window.get_compositor_private())
            tile(window, zone, monitor);
        return GLib.SOURCE_REMOVE;
    });
}

// --- Window menu --------------------------------------------------------------

function buildMenu(window) {
    origBuildMenu.call(this, window);
    if (window.get_window_type() !== Meta.WindowType.NORMAL)
        return;

    const menu = this;
    const later = fn => {
        menu.close(false);
        GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            if (window.get_compositor_private())
                fn();
            return GLib.SOURCE_REMOVE;
        });
    };

    // Inserted after Minimize / Maximize.
    let pos = 2;
    this.addMenuItem(new PopupMenu.PopupSeparatorMenuItem(), pos++);

    if (window.allows_resize()) {
        const item = new PopupMenu.PopupBaseMenuItem({
            activate: false,
            hover: false,
            focusOnHover: false,
            style_class: 'snap-menu-item',
        });
        const picker = buildPicker(z => later(() => tile(window, z)));
        item.addActor(picker.actor, { expand: true, span: -1 });
        this.addMenuItem(item, pos++);
    }

    const add = (label, icon, fn, sensitive = true) => {
        const item = new WindowMenu.MnemonicLeftOrnamentedMenuItem(label);
        item.setIcon(icon);
        item.connect('activate', () => later(fn));
        if (!sensitive)
            item.setSensitive(false);
        this.addMenuItem(item, pos++);
        this._items.push(item);
    };
    add('_Fill', 'xsi-view-fullscreen-symbolic',
        () => { untile(window); window.maximize(Meta.MaximizeFlags.BOTH); },
        window.can_maximize());
    add('C_enter', 'xsi-zoom-fit-best-symbolic', () => center(window), window.allows_move());
    add('Re_store', 'xsi-view-restore-symbolic', () => untile(window),
        !!window.get_maximized() || window.is_fullscreen());
    add(window.is_fullscreen() ? 'Leave F_ull Screen' : 'F_ull Screen (own desktop)',
        'xsi-view-fullscreen-symbolic',
        () => window.is_fullscreen() ? window.unmake_fullscreen() : window.make_fullscreen());
    this.addMenuItem(new PopupMenu.PopupSeparatorMenuItem(), pos++);
}

function showMenuForFocused() {
    const window = global.display.focus_window;
    if (!window || window.get_window_type() !== Meta.WindowType.NORMAL)
        return;
    const f = window.get_frame_rect();
    // Anchor it under the titlebar's right end, near where the buttons are.
    const rect = new Meta.Rectangle({ x: f.x + f.width - 220, y: f.y + 30, width: 1, height: 1 });
    Main.wm._windowMenuManager.showWindowMenuForWindow(window, Meta.WindowMenuType.WM, rect);
}

// --- Extension entry points ---------------------------------------------------

function init() {}

function enable() {
    origBuildMenu = WindowMenu.WindowMenu.prototype._buildMenu;
    WindowMenu.WindowMenu.prototype._buildMenu = buildMenu;
    grabBeginId = global.display.connect('grab-op-begin', onGrabBegin);
    grabEndId = global.display.connect('grab-op-end', onGrabEnd);
    Main.keybindingManager.addHotKey(HOTKEY, '<Super>z', showMenuForFocused);
}

function disable() {
    Main.keybindingManager.removeHotKey(HOTKEY);
    if (grabBeginId)
        global.display.disconnect(grabBeginId);
    if (grabEndId)
        global.display.disconnect(grabEndId);
    grabBeginId = grabEndId = 0;
    endDrag();
    if (origBuildMenu)
        WindowMenu.WindowMenu.prototype._buildMenu = origBuildMenu;
    origBuildMenu = null;
}
