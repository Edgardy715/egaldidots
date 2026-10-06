const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const views = {
  Appearance: 'AppearanceView', Auth: 'AuthPromptView', Calendar: 'CalendarView',
  Clipboard: 'ClipboardView', Connectivity: 'ConnectivityView', Launcher: 'LauncherView',
  Media: 'MediaView', Mixer: 'MixerView', Notifs: 'NotifsView', Overview: 'OverviewView',
  Session: 'SessionView', Utils: 'QuickControlsView', Wallpaper: 'WallpaperView', Workspaces: 'WorkspacesView'
};
const surfaces = fs.readdirSync(path.join(root, 'surfaces')).filter(n => n.endsWith('Surface.qml')).map(n => n.slice(0, -11)).sort();
assert.deepEqual(surfaces, Object.keys(views).sort(), 'Every surface must have an audited presentation boundary');
const forbidden = [
  /\b(?:Players|Cava|Hyprland|WinMap|Apps|AppSearch|Auth|Config|Session|Nmcli|Bluetooth|Pipewire|Notifs|Wallpapers|KeepAwake|Brightness)\./,
  /\b(?:Process|FileView|StdioCollector|XMLHttpRequest)\s*[{(]/,
  /\b(?:execDetached|openUrlExternally)\s*\(/,
  /\b\w+(?:Controller|Adapter|Session|Data)\s*\{/,
  /\.(?:invoke|lock|unlock|execute)\s*\(/
];
for (const view of new Set([...Object.values(views), 'NotifCardView', 'PillHeaderView', 'PillMorphMotion', 'OverlayInputPolicy'])) {
  const file = path.join(root, 'components', view + '.qml');
  assert.ok(fs.existsSync(file), view + ' is missing');
  const code = fs.readFileSync(file, 'utf8').replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  for (const expression of forbidden) assert.ok(!expression.test(code), view + ' crosses its presentation boundary: ' + expression);
}
console.log('PASS: all 14 surfaces, pill header/motion and overlay policy have no desktop services, native actions, IO or embedded adapters');
