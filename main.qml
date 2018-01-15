import QtQuick 2.9
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.3
import backend 1.0

ApplicationWindow {
    visible: true
    width: 640
    height: 480
    title: qsTr("Minecraft Launcher")

    property bool inProgress: true

    BackEnd {
        id: backend
        property var ready: []
        onReady: function (content, id) {
            var func = ready[id];
            if (func !== null)
                func(content);
            delete ready[id];
        }
    }

    Item {
        id: mc
        property string baseDir: "minecraft"
        property int requests: 0

        function download(url, path, onReady) {
            backend.ready[requests] = onReady;
            backend.download(Qt.resolvedUrl(url), baseDir + "/" + path,
                             false, requests++);
        }

        function get(url, path, onReady) {
            backend.ready[requests] = onReady;
            backend.download(Qt.resolvedUrl(url), baseDir + "/" + path,
                             true, requests++);
        }

        function updateManifest() {
            inProgress = true;

            var doc = new XMLHttpRequest();
            doc.onreadystatechange = function() {
                if (doc.readyState === XMLHttpRequest.DONE) {
                    inProgress = false;
                    var manifest = JSON.parse(doc.responseText);
                    if (manifest === null)
                        return;
                    list.model = manifest.versions;
                }
            }

            doc.open("GET", "https://launchermeta.mojang.com/mc/game/version_manifest.json");
            doc.send();
        }

        function downloadArtifact(artifact, type) {
            download(artifact.url, type + "/" + artifact.path);
        }

        function downloadLibraries(libraries) {
            for (var i in libraries)
                downloadArtifact(libraries[i].downloads.artifact, "libraries");
        }

        function start(version) {
            var path = "versions/" + version.id + "/" + version.id + ".json";
            get(version.url, path, function (content) {
                var obj = JSON.parse(content);
                downloadLibraries(obj.libraries);
            });
        }
    }

    BusyIndicator {
        anchors.fill: parent
        visible: inProgress
    }

    ColumnLayout {
        anchors.fill: parent
        enabled: !inProgress
        spacing: 0

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

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

                onCurrentIndexChanged: function(index) {
                    var obj = list.model[list.currentIndex];
                    text.text = JSON.stringify(obj);
                }
            }
        }

        Text {
            id: text
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            Layout.fillWidth: true
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Button {
            Layout.fillWidth: true
            text: qsTr("Start!")

            onClicked: mc.start(list.model[list.currentIndex])
        }
    }

    Component.onCompleted: mc.updateManifest()
}
