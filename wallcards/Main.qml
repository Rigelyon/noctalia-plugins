import QtQuick
import Quickshell.Io

Item {
  id: root
  property var pluginApi: null
  property var window: null

  IpcHandler {
    target: "plugin:wallcards"

    function toggle() {
      root.window === null ? show() : hide();
    }

    function show() {
      root.openWindow();
    }

    function hide() {
      root.closeWindow();
    }
  }

  function openWindow() {
    if (window === null)
      window = Qt.createComponent("WallcardsWindow.qml").createObject(root, {
        pluginApi: Qt.binding(function() { return root.pluginApi })
      });

    window.visible = true;
  }

  function closeWindow() {
    if (window !== null)
      window.destroy();
  }
}
