var baseDir = "minecraft";
var manifestUrl = "https://launchermeta.mojang.com/mc/game/version_manifest.json";
var assetsUrl = "http://resources.download.minecraft.net";

var params = {
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
};

var requestId = 0;
var versions = [];

// https://stackoverflow.com/a/9229821
function uniq(a) {
    var seen = {};
    return a.filter(function(item) {
        return seen.hasOwnProperty(item) ? false : (seen[item] = true);
    });
}

function download(url, path, sha1, onReady) {
    backend.requests[requestId] = onReady;
    backend.requestNum++;
    backend.download(url, baseDir + "/" + path, false, requestId++, sha1);
}

function get(url, path, sha1, onReady) {
    backend.requests[requestId] = onReady;
    backend.requestNum++;
    backend.download(url, baseDir + "/" + path, true, requestId++, sha1);
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
    download(artifact.url, type + "/" + artifact.path, artifact.sha1);
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
    download(assetsUrl + "/" + hash, path, asset.hash);
}

function downloadAssets(index) {
    var path = "assets/indexes/" + index.id + ".json";
    get(index.url, path, index.sha1, function(content) {
        var obj = JSON.parse(content);
        for (var key in obj.objects)
            downloadAsset(obj.objects[key]);
    });
}

function downloadClient(obj, id) {
    download(obj.client.url, "versions/" + id + "/" + id + ".jar", obj.client.sha1);
    download(obj.server.url, "versions/" + id + "/" + id + "-server.jar", obj.server.sha1);
}

function downloadLogConfig(obj) {
    download(obj.url, "assets/log_configs/" + obj.id, obj.sha1);
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
    get(version.url, path, null, function(content) {
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
