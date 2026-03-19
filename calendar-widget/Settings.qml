import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root
    implicitWidth: 400
    implicitHeight: 180

    property var pluginApi: null
    
    // Clean modern syntax using optional chaining
    readonly property var cfg: pluginApi?.pluginSettings ?? ({})
    readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})
    readonly property bool startOnMonday: cfg.startOnMonday ?? defaults.startOnMonday ?? true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NText {
            text: "Calendar Preferences"
            font.bold: true
            font.pointSize: Style.fontSizeM
            color: Color.mPrimary
        }

        RowLayout {
            Layout.fillWidth: true
            NText { 
                text: "Start week on Monday"
                Layout.fillWidth: true
                color: Color.mOnSurface
            }
            
            NToggle { 
                checked: root.startOnMonday
                onToggled: {
                    if (pluginApi) {
                        pluginApi.pluginSettings.startOnMonday = checked;
                        pluginApi.saveSettings();
                        // Logging with the singleton method
                        Logger.i("CalendarPlugin", "Updated startOnMonday to: " + checked);
                    }
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
