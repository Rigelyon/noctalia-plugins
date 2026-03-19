import QtQuick
import Quickshell

Item {
    id: root
    
    // Noctalia injects this automatically based on your manifest.json
    property var pluginApi: null

    Component.onCompleted: {
        // Calling the Logger as a singleton (No object needed)
        Logger.i("CalendarPlugin", "Plugin initialized successfully via auto-registration.");
    }
}
