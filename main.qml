import QtQuick 2.9
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import backend 1.0

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
            requestNum--;
        }

        onDone: function(id) {
            requestNum--;
        }

        onRequestNumChanged: function() {
            status.text = "Active requests: " + requestNum;
            if (requestNum == 0 && finish !== undefined)
                finish();
        }
    }

    Item {
        id: mc
        property string baseDir: "minecraft"
        property string manifestUrl: "https://launchermeta.mojang.com/mc/game/version_manifest.json"
        property string assetsUrl: "http://resources.download.minecraft.net"

        property var params: ({
            auth_player_name: "Steve",
            auth_uuid: 0,
            auth_access_token: 0,
            user_type: "legacy",

            game_directory: ".",
            assets_root: "assets",
            game_assets: "assets",
            natives_directory: "natives",

            launcher_name: "custom",
            launcher_version: "0.1",

            is_demo_user: false,
            has_custom_resolution: false,
            resolution_width: 800,
            resolution_height: 600,

            os: "windows",
        })

        property int requestId: 0
        property var versions: []

        // https://stackoverflow.com/a/9229821
        function uniq(a) {
            var seen = {};
            return a.filter(function(item) {
                return seen.hasOwnProperty(item) ? false : (seen[item] = true);
            });
        }

        function download(url, path, onReady) {
            backend.requests[requestId] = onReady;
            backend.requestNum++;
            backend.download(url, baseDir + "/" + path, false, requestId++);
        }

        function get(url, path, onReady) {
            backend.requests[requestId] = onReady;
            backend.requestNum++;
            backend.download(url, baseDir + "/" + path, true, requestId++);
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

                    versions = manifest.versions;
                    var model = [];
                    for (var i in versions) {
                        var v = versions[i];
                        model.push(v.type + " " + v.id);
                    }
                    list.model = model;
                }
            }

            doc.open("GET", manifestUrl);
            doc.send();
        }

        function checkRules(rules) {
            if (rules === undefined)
                return true;
            for (var i in rules) {
                var rule = rules[i];
                // AND operation
                var match = true;
                // TODO: Check OS version
                if (rule.os !== undefined) {
                    if (rule.os.name !== params["os"])
                        match = false;
                }
                if (rule.features !== undefined) {
                    for (var key in rule.features)
                        if (params[key] !== rule.features[key])
                            match = false;
                }
                return match == (rule.action === "allow");
            }
            return false;
        }

        function downloadArtifact(artifact, type) {
            download(artifact.url, type + "/" + artifact.path);
        }

        function downloadLibraries(libs) {
            for (var i in libs) {
                var lib = libs[i];
                if (!checkRules(lib.rules))
                    continue;
                if (lib.natives !== undefined) {
                    var natives = lib.natives[params["os"]];
                    if (natives !== undefined)
                        downloadArtifact(lib.downloads.classifiers[natives], "libraries");
                }
                downloadArtifact(lib.downloads.artifact, "libraries");
            }
        }

        function downloadAsset(asset) {
            var hash = asset.hash.substr(0, 2) + "/" + asset.hash;
            var path = "assets/objects/" + hash;
            download(assetsUrl + "/" + hash, path);
        }

        function downloadAssets(index) {
            var path = "assets/indexes/" + index.id + ".json";
            get(index.url, path, function(content) {
                var obj = JSON.parse(content);
                for (var key in obj.objects)
                    downloadAsset(obj.objects[key]);
            });
        }

        function downloadClient(obj, id) {
            download(obj.client.url, "versions/" + id + "/" + id + ".jar");
            download(obj.server.url, "versions/" + id + "/" + id + "-server.jar");
        }

        function downloadLogConfig(obj) {
            download(obj.url, "assets/log_configs/" + obj.id);
        }

        function parseArguments(args) {
            var a = [];
            if (typeof(args) === "string")
                args = [args];
            for (var i in args) {
                var arg = args[i]
                if (typeof(arg) === "string") {
                    a.push(arg.replace(/\$\{(.*?)\}/g, function(m0, m1) {
                        return params[m1];
                    }));
                } else {
                    if (!checkRules(arg.rules))
                        continue;
                    a = a.concat(parseArguments(arg.value));
                }
            }
            return a;
        }

        function classPaths(libs, id) {
            var sep = params.os === "windows" ? ";" : ":";
            var cp = "";
            for (var i in libs) {
                var lib = libs[i];
                if (!checkRules(lib.rules))
                    continue;
                if (lib.natives !== undefined) {
                    var natives = lib.natives[params["os"]];
                    if (natives !== undefined)
                        cp = cp.concat("libraries/", lib.downloads.classifiers[natives].path, sep);
                }
                cp = cp.concat("libraries/", lib.downloads.artifact.path, sep);
            }
            cp = cp.concat("versions/" + id + "/" + id + ".jar");
            return cp;
        }

        function launch(obj) {
            params["version_name"] = obj.id;
            params["assets_index_name"] = obj.assets;
            params["version_type"] = obj.type;
            params["classpath"] = classPaths(obj.libraries, obj.id);
            params["path"] = "assets/log_configs/" + obj.logging.client.file.id;
            var args = parseArguments(obj.arguments.jvm);
            args = args.concat(parseArguments(obj.logging.client.argument));
            args.push(obj.mainClass);
            args = args.concat(parseArguments(obj.arguments.game));
            if (backend.exec("java.exe", args, baseDir))
                msg.visible = true;
        }

        function start(index) {
            inProgress = true;
            var version = versions[index];
            var path = "versions/" + version.id + "/" + version.id + ".json";
            get(version.url, path, function(content) {
                var obj = JSON.parse(content);
                downloadLibraries(obj.libraries);
                downloadAssets(obj.assetIndex);
                downloadLogConfig(obj.logging.client.file);
                downloadClient(obj.downloads, version.id);
                backend.finish = function() {
                    inProgress = false;
                    launch(obj);
                }
            });
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
            onClicked: mc.start(list.currentIndex)
        }
    }

    Component.onCompleted: mc.updateManifest()
}
