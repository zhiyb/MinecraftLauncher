import QtQuick 2.9
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import backend 1.0
import "mc.js" as MC

ApplicationWindow {
    visible: true
    width: 640
    height: 480
    title: qsTr("Minecraft Launcher")

    property bool inProgress: true

    BackEnd {
        id: backend
        property var requests: ({})
        property int requestNum: 0
        property var finish

        onReady: function(content, id) {
            var func = requests[id];
            if (func !== undefined)
                func(content);
            delete requests[id];
            requestNum--;
        }

        onDone: function(id) {
            delete requests[id];
            requestNum--;
        }

        onRequestNumChanged: function() {
            status.text = "Active requests: " + requestNum;
            if (requestNum == 0 && finish !== undefined)
                finish();
        }
    }

    BusyIndicator {
        anchors.fill: parent
        visible: inProgress
    }

    MessageDialog {
        id: msg
        text: "Program executed."
        visible: false
    }

    ColumnLayout {
        anchors.fill: parent
        enabled: !inProgress

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: list
                width: parent.width
                delegate: ItemDelegate {
                    text: list.model[index]
                    width: parent.width
                    MouseArea {
                        anchors.fill: parent
                        onClicked: list.currentIndex = index
                    }
                }
                highlightMoveDuration: 100
                highlight: Rectangle {
                    color: "blue"
                    radius: 5
                    opacity: 0.6
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.minimumHeight: 2
            Layout.maximumHeight: 2
            color: "black"
        }

        Text {
            id: status
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            Layout.fillWidth: true
        }

        Button {
            Layout.fillWidth: true
            text: qsTr("Start!")
            onClicked: MC.start(list.currentIndex)
        }
    }

    Component.onCompleted: MC.updateManifest()
}
