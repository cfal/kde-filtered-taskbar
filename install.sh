#!/bin/bash

# Filtered Taskbar Installation Script

set -e

WIDGET_ID="org.kde.plasma.filtered.taskbar"
WIDGET_DIR="$HOME/.local/share/plasma/plasmoids/$WIDGET_ID"

# Check if running from repository root
if [ ! -d "$WIDGET_ID" ]; then
    echo "Error: $WIDGET_ID directory not found."
    echo "Please run this script from the repository root directory."
    exit 1
fi

echo "Installing Filtered Taskbar widget..."

# Create plasmoids directory if it doesn't exist
mkdir -p "$HOME/.local/share/plasma/plasmoids"

# Remove existing widget if it exists
if [ -d "$WIDGET_DIR" ]; then
    echo "Removing existing widget installation..."
    rm -rf "$WIDGET_DIR"
fi

# Copy widget files
cp -r "$WIDGET_ID" "$WIDGET_DIR"

# Decide whether to use the system private module or provide a local shim.
echo "Checking for system QML module org.kde.plasma.private.taskmanager..."
SYSTEM_PRIVATE="$(find /usr /usr/lib /usr/lib64 /usr/share -maxdepth 6 -type d -path "*/org.kde.plasma.private.taskmanager" 2>/dev/null | head -n1 || true)"

if [ -n "$SYSTEM_PRIVATE" ]; then
    echo "System private module found at: $SYSTEM_PRIVATE"
    echo "Patching installed plasmoid to import system private module..."
    for f in "$WIDGET_DIR"/contents/ui/{main.qml,Task.qml,ContextMenu.qml}; do
        if [ -f "$f" ]; then
            sed -i "s|import \"TaskManagerApplet\" as TaskManagerApplet|import org.kde.plasma.private.taskmanager as TaskManagerApplet|g" "$f" || true
            sed -i "s|import org.kde.taskmanager as TaskManagerApplet|import org.kde.plasma.private.taskmanager as TaskManagerApplet|g" "$f" || true
        fi
    done
    # Remove any shipped shim
    if [ -d "$WIDGET_DIR/contents/ui/TaskManagerApplet" ]; then
        rm -rf "$WIDGET_DIR/contents/ui/TaskManagerApplet"
    fi
else
    echo "System private module not found; installing a local shim so the widget runs without extra steps."
    SHIM_DIR="$WIDGET_DIR/contents/ui/TaskManagerApplet"
    mkdir -p "$SHIM_DIR"

    cat > "$SHIM_DIR/Backend.qml" <<'EOF'
import QtQuick 2.0

// Minimal shim for TaskManagerApplet.Backend to allow the plasmoid to load
// when the system private module is not installed. This provides the
// bits of the API used by this plasmoid. It intentionally does not
// implement full behavior — install the system module for full features.

QtObject {
    id: backendShim

    signal addLauncher(string url)
    signal showAllPlaces()

    function isApplication(url) { return false; }
    function placesActions(launcherUrl, showAllPlaces, menu) { return []; }
    function recentDocumentActions(launcherUrl, menu) { return []; }
    function jumpListActions(launcherUrl, menu) { return []; }
    function tryDecodeApplicationsUrl(url) { return url; }

    function globalRect(item) {
        if (!item) return { x: 0, y: 0, width: 0, height: 0 };
        return {
            x: typeof item.x === 'number' ? item.x : 0,
            y: typeof item.y === 'number' ? item.y : 0,
            width: typeof item.width === 'number' ? item.width : 0,
            height: typeof item.height === 'number' ? item.height : 0
        };
    }
}
EOF

    cat > "$SHIM_DIR/SmartLauncherItem.qml" <<'EOF'
import QtQuick 2.0

Item {
    property url launcherUrl: ""
    property bool countVisible: false
    property int count: 0
    property bool urgent: false
    property bool progressVisible: false
    property int progress: 0
    width: 1
    height: 1
}
EOF

    # Ensure installed files import the local shim
    for f in "$WIDGET_DIR"/contents/ui/{main.qml,Task.qml,ContextMenu.qml}; do
        if [ -f "$f" ]; then
            sed -i "s|import org.kde.taskmanager as TaskManagerApplet|import \"TaskManagerApplet\" as TaskManagerApplet|g" "$f" || true
            sed -i "s|import org.kde.plasma.private.taskmanager as TaskManagerApplet|import \"TaskManagerApplet\" as TaskManagerApplet|g" "$f" || true
        fi
    done
fi

echo "Restarting Plasma shell to load the widget..."
kquitapp6 plasmashell && sleep 1 && kstart5 plasmashell > /dev/null 2>&1 &
echo "Plasma shell is restarting... please wait a moment for it to complete."

echo "Installation complete!"
echo ""
echo "To add the widget:"
echo "1. Right-click on your panel"
echo "2. Select 'Add Widgets...'"
echo "3. Find 'Filtered Taskbar' in the list"
echo "4. Drag it to your panel"
echo ""
echo "Configure filtering in widget settings (right-click → Configure Filtered Taskbar → Applications tab)"