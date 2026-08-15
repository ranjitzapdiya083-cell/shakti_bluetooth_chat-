allprojects {
    repositories {
        google()
        mavenCentral()
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
// --- Compatibility patch for legacy plugins (e.g. flutter_bluetooth_serial) ---
// Old/unmaintained plugins still declare `package="..."` inside their own
// AndroidManifest.xml instead of setting `namespace` in build.gradle. Modern
// AGP treats that as a hard build failure ("Setting the namespace via the
// package attribute ... is no longer supported"). This block auto-fixes it
// for every subproject at build time, without touching the plugin's source
// or your Dart code, so it keeps working even on a fresh CI checkout where
// the pub-cache is downloaded from scratch every run.
subprojects {
    plugins.withId("com.android.library") {
        afterEvaluate {
            val androidExt = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            val manifestFile = file("src/main/AndroidManifest.xml")
            if (androidExt != null && manifestFile.exists()) {
                val text = manifestFile.readText()
                val match = Regex("package=\"([^\"]+)\"").find(text)
                if (match != null) {
                    if (androidExt.namespace.isNullOrBlank()) {
                        androidExt.namespace = match.groupValues[1]
                    }
                    val patched = text.replace(Regex("\\s+package=\"[^\"]+\""), "")
                    if (patched != text) {
                        manifestFile.writeText(patched)
                    }
                }
            }
        }
    }
}
// --- Compile SDK alignment patch ---
// Legacy plugins (e.g. flutter_bluetooth_serial) still hardcode an old
// compileSdkVersion (28/30). When their AAR resources get merged with
// modern AndroidX resources pulled in by newer Flutter/AGP versions, AAPT
// fails with errors like "resource android:attr/lStar not found" because
// attributes introduced in newer API levels aren't known at the plugin's
// old compileSdk. Forcing every subproject to compile against the same
// (newer) SDK as the app fixes this without editing the plugin itself.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.let { androidExt ->
            androidExt.compileSdkVersion(35)
        }
    }
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
