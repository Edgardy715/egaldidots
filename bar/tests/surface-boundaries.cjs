const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const overlay = fs.readFileSync(path.join(root, 'windows/IslandOverlay.qml'), 'utf8');
for (const module of ['workspaceModule', 'userModule', 'statusModule', 'mediaModule']) {
  assert.ok(overlay.includes(`width: sideModules.${module}.interactive ? sideModules.${module}.width : 0`)
    && overlay.includes(`height: sideModules.${module}.interactive ? sideModules.${module}.height : 0`),
    `${module} must receive pointer input while interactive and release it when hidden`);
}
const views = {
  Appearance: 'AppearanceView', Auth: 'AuthPromptView', Calendar: 'CalendarView',
  Clipboard: 'ClipboardView', Connectivity: 'ConnectivityView', Focus: 'ActivityView', Launcher: 'LauncherView',
  Media: 'MediaView', Mixer: 'MixerView', Notifs: 'NotifsView', Overview: 'OverviewView', Recording: 'ActivityView',
  Session: 'SessionView', Utils: 'QuickControlsView', Wallpaper: 'WallpaperView', Workspaces: 'WorkspacesView'
};
const surfaces = fs.readdirSync(path.join(root, 'surfaces')).filter(n => n.endsWith('Surface.qml')).map(n => n.slice(0, -11)).sort();
assert.deepEqual(surfaces, [...Object.keys(views), 'Settings'].sort(), 'Every surface must have an audited presentation boundary');
assert.ok(fs.readFileSync(path.join(root, 'surfaces', 'SettingsSurface.qml'), 'utf8').includes('EdotsWindow'),
  'Settings surface hosts the existing Config editor');
const forbidden = [
  /\b(?:Players|Cava|Hyprland|WinMap|Apps|AppSearch|Auth|Config|Session|Nmcli|Bluetooth|Pipewire|Notifs|Wallpapers|KeepAwake|Brightness|Recording|FocusSession)\./,
  /\b(?:Process|FileView|StdioCollector|XMLHttpRequest)\s*[{(]/,
  /\b(?:execDetached|openUrlExternally)\s*\(/,
  /\b\w+(?:Controller|Adapter|Session|Data)\s*\{/,
  /\.(?:invoke|lock|unlock|execute)\s*\(/
];
for (const view of new Set([...Object.values(views), 'FocusTimerView', 'RecordingView', 'RecordingGlyph', 'FluidRecordingCompanion', 'NotifCardView', 'PillHeaderView', 'PillMorphMotion', 'OverlayInputPolicy', 'CompactMediaStatus'])) {
  const file = path.join(root, 'components', view + '.qml');
  assert.ok(fs.existsSync(file), view + ' is missing');
  const code = fs.readFileSync(file, 'utf8').replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  for (const expression of forbidden) assert.ok(!expression.test(code), view + ' crosses its presentation boundary: ' + expression);
}
console.log('PASS: 16 shell surfaces, settings editor, activity views, pill header/motion and overlay policy have audited boundaries');
