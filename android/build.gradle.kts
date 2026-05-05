allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// AGP 8+ requires each Android module to define a `namespace`.
// Some older Flutter plugins (e.g. isar_flutter_libs 3.1.x) don't specify one.
// Inject a namespace here to keep builds working without modifying pub-cache.
subprojects {
    afterEvaluate {
        if (name == "isar_flutter_libs") {
            val androidExtension = extensions.findByName("android")
            if (androidExtension != null) {
                try {
                    val setNamespace = androidExtension.javaClass.methods.firstOrNull { m ->
                        m.name == "setNamespace" && m.parameterTypes.size == 1 &&
                            m.parameterTypes[0] == String::class.java
                    }
                    setNamespace?.invoke(androidExtension, "dev.isar.isar_flutter_libs")

                    // Ensure plugin module compiles against a modern SDK (needed for android:attr/lStar, etc).
                    val setCompileSdkVersion = androidExtension.javaClass.methods.firstOrNull { m ->
                        (m.name == "setCompileSdkVersion" || m.name == "compileSdkVersion") &&
                            m.parameterTypes.size == 1 &&
                            (m.parameterTypes[0] == Int::class.javaPrimitiveType ||
                                m.parameterTypes[0] == Int::class.java)
                    }
                    setCompileSdkVersion?.invoke(androidExtension, 35)
                } catch (_: Throwable) {
                    // Best-effort; if API differs, Gradle will still report the cause.
                }
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
