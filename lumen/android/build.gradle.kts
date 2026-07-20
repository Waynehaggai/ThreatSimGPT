allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force every Android module (the app and all Flutter plugins) to compile
// against SDK 36. Some transitive plugins (e.g. flutter_plugin_android_lifecycle)
// require their consumers to compile against 36, but Flutter 3.44's default
// compileSdk is 34, so plugin modules like :file_picker otherwise stay at 34 and
// fail the AAR-metadata check. Applied reflectively to stay agnostic to the
// Android Gradle Plugin's DSL version.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val cls = androidExt.javaClass
        runCatching {
            cls.getMethod("setCompileSdk", Integer::class.java).invoke(androidExt, 36)
        }.onFailure {
            runCatching {
                cls.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    .invoke(androidExt, 36)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
