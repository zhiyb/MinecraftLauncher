import qbs

Project {
    minimumQbsVersion: "1.7.1"

    FileTagger {
        patterns: "*.dll"
        fileTags: ["dll"]
    }

    Product {
        name: "OpenSSL Win64"
        condition: qbs.targetOS.contains("windows")
        files: ["openssl-1.0.2n-x64_86-win64/**"]

        Group {
            fileTagsFilter: "dll"
            qbs.install: true
        }
    }

    Product {
        name: "zlib Win64"
        condition: qbs.targetOS.contains("windows")
        files: ["zlib-win64/**"]

        Export {
            Depends {name: "cpp"}
            cpp.includePaths: ["zlib-win64/include"]
            cpp.libraryPaths: ["zlib-win64/lib"]

            Properties {
                condition: qbs.buildVariant == "debug"
                cpp.staticLibraries: ["zlibstaticd"]
            }

            Properties {
                condition: qbs.buildVariant == "release"
                cpp.staticLibraries: ["zlibstatic"]
            }
        }
    }

    Product {
        name: "Zipper Win64"
        condition: qbs.targetOS.contains("windows")
        files: ["zipper-win64/**"]

        Export {
            Depends {name: "cpp"}
            Depends {name: "zlib Win64"}
            cpp.includePaths: ["zipper-win64/include/zipper"]
            cpp.libraryPaths: ["zipper-win64/lib"]

            Properties {
                condition: qbs.buildVariant == "debug"
                cpp.staticLibraries: ["libZipper-staticd"]
            }

            Properties {
                condition: qbs.buildVariant == "release"
                cpp.staticLibraries: ["libZipper-static"]
            }
        }
    }

    CppApplication {
        Depends {name: "Qt.core"}
        Depends {name: "Qt.quick"}
        Depends {
            name: "OpenSSL Win64"
            condition: qbs.targetOS.contains("windows")
        }
        Depends {
            name: "Zipper Win64"
            condition: qbs.targetOS.contains("windows")
        }

        // Additional import path used to resolve QML modules in Qt Creator's code model
        property pathList qmlImportPaths: []

        cpp.cxxLanguageVersion: "c++11"

        cpp.defines: [
            // The following define makes your compiler emit warnings if you use
            // any feature of Qt which as been marked deprecated (the exact warnings
            // depend on your compiler). Please consult the documentation of the
            // deprecated API in order to know how to port your code away from it.
            "QT_DEPRECATED_WARNINGS",

            // You can also make your code fail to compile if you use deprecated APIs.
            // In order to do so, uncomment the following line.
            // You can also select to disable deprecated APIs only up to a certain version of Qt.
            //"QT_DISABLE_DEPRECATED_BEFORE=0x060000" // disables all the APIs deprecated before Qt 6.0.0
        ]

        files: [
            "backend.cpp",
            "backend.h",
            "main.cpp",
            "qml.qrc",
        ]

        Group {     // Properties for the produced executable
            fileTagsFilter: "application"
            qbs.install: true
        }
    }
}
