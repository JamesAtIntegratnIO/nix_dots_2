const Meta = imports.gi.Meta;
const Cinnamon = imports.gi.Cinnamon;
const Main = imports.ui.main;
const Mainloop = imports.mainloop;

let windows = new Map();
let createdId = 0;
let pending = new Set();

function applicationName(window) {
    const tracker = Cinnamon.WindowTracker.get_default();
    const app = tracker.get_window_app(window);
    return (app && app.get_name()) || window.get_wm_class() ||
        window.get_title() || 'Fullscreen';
}

function workspaceExists(workspace) {
    const manager = global.workspace_manager;
    for (let i = 0; i < manager.n_workspaces; i++) {
        if (manager.get_workspace_by_index(i) === workspace)
            return true;
    }
    return false;
}

function removeEmptySpace(workspace) {
    if (workspaceExists(workspace) &&
        global.workspace_manager.n_workspaces > 1 &&
        !workspace.list_windows().some(window => !window.is_on_all_workspaces()))
        Main._removeWorkspace(workspace);
}

function restore(window, record, closing = false) {
    if (!record.space)
        return;
    const space = record.space;
    record.space = null;
    // A manually moved window should stay where the user put it.
    const stillInSpace = window.get_workspace() === space;
    const origin = workspaceExists(record.origin) ? record.origin :
        global.workspace_manager.get_workspace_by_index(0);
    if (!closing && stillInSpace)
        window.change_workspace(origin);
    if (!closing && stillInSpace && global.workspace_manager.get_active_workspace() === space)
        origin.activate(global.get_current_time());
    // On close, wait until Muffin has removed the window from its workspace.
    const id = Mainloop.idle_add(() => {
        pending.delete(id);
        if (closing && stillInSpace && global.workspace_manager.get_active_workspace() === space)
            origin.activate(global.get_current_time());
        removeEmptySpace(space);
        return false;
    });
    pending.add(id);
}

function update(window) {
    const record = windows.get(window);
    if (!record)
        return;
    if (!window.is_fullscreen()) {
        restore(window, record);
        return;
    }
    if (record.space || window.is_on_all_workspaces() ||
        window.get_window_type() !== Meta.WindowType.NORMAL ||
        window.get_transient_for())
        return;

    record.origin = window.get_workspace();
    const focused = global.display.focus_window === window;
    record.space = global.workspace_manager.append_new_workspace(false, global.get_current_time());
    Main.setWorkspaceName(record.space.index(), applicationName(window));
    window.change_workspace(record.space);
    // Background applications must not steal the current workspace.
    if (focused)
        record.space.activate_with_focus(window, global.get_current_time());
}

function queueUpdate(window) {
    const record = windows.get(window);
    if (!record || record.updateId)
        return;
    // Fullscreen notifications precede Muffin's resize and Cinnamon's animation.
    // Switching workspaces during that animation can restore stale actor positions.
    const id = Mainloop.timeout_add(30, () => {
        const actor = window.get_compositor_private();
        if (actor && (Main.wm._resizePending.has(actor) ||
            Main.wm._resizing.has(actor) || actor.origX !== undefined))
            return true;
        pending.delete(id);
        record.updateId = 0;
        update(window);
        return false;
    });
    record.updateId = id;
    pending.add(id);
}

function watch(window) {
    if (windows.has(window))
        return;
    const record = { origin: null, space: null, signals: [], updateId: 0 };
    windows.set(window, record);
    record.signals.push(window.connect('notify::fullscreen', () => queueUpdate(window)));
    record.signals.push(window.connect('unmanaged', () => {
        if (record.updateId) {
            Mainloop.source_remove(record.updateId);
            pending.delete(record.updateId);
            record.updateId = 0;
        }
        restore(window, record, true);
        for (const id of record.signals)
            window.disconnect(id);
        windows.delete(window);
    }));
    // New windows may not yet have their workspace or initial fullscreen state.
    queueUpdate(window);
}

function init() {}

function enable() {
    createdId = global.display.connect('window-created', (_display, window) => watch(window));
    for (const actor of global.get_window_actors())
        watch(actor.meta_window);
}

function disable() {
    if (createdId)
        global.display.disconnect(createdId);
    createdId = 0;
    for (const id of pending)
        Mainloop.source_remove(id);
    pending.clear();
    const spaces = [];
    for (const [window, record] of windows) {
        for (const id of record.signals)
            window.disconnect(id);
        if (record.space) {
            spaces.push(record.space);
            if (window.get_workspace() === record.space && workspaceExists(record.origin))
                window.change_workspace(record.origin);
        }
    }
    windows.clear();
    for (const space of spaces)
        removeEmptySpace(space);
}
