.pragma library

// Whether the last powerprofilesctl read worked. The adapter is rebuilt on every
// open; remembering the answer keeps a machine without the daemon from showing
// the profile card for a moment and then folding it away.
var available = true
