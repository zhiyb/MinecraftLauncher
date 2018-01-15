import QtQuick 2.9
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.3

ApplicationWindow {
    visible: true
    width: 640
    height: 480
    title: qsTr("Minecraft Launcher")

    property bool inProgress: true

    BusyIndicator {
        anchors.fill: parent
        visible: inProgress
    }

    ColumnLayout {
        anchors.fill: parent
        enabled: !inProgress

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                height: parent.height
                delegate: ItemDelegate {
                    text: list.model[index].type + " " + list.model[index].id
                    width: parent.width

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            list.currentIndex = index
                        }
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

        Button {
            Layout.fillWidth: true
            text: qsTr("Start!")
        }
    }

    Component.onCompleted: function() {
        var doc = new XMLHttpRequest();
        doc.onreadystatechange = function() {
            if (doc.readyState === XMLHttpRequest.DONE) {
                inProgress = false;
                var manifest = JSON.parse(doc.responseText);
                if (manifest === null)
                    return;
                list.model = manifest.versions;
                console.log(JSON.stringify(manifest.versions));
            }
        }

        doc.open("GET", "https://launchermeta.mojang.com/mc/game/version_manifest.json");
        doc.send();
    }
}
