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
// NOTE: compileSdk for flutter_bluetooth_serial is patched directly in its
// build.gradle file by the CI workflow (see "Fix flutter_bluetooth_serial
// namespace and compileSdk" step in .github/workflows/build-apk.yml) rather
// than here. AGP reads compileSdk eagerly as soon as the plugin's own
// build.gradle sets it, so overriding it from the root project's
// subprojects {} block (even via afterEvaluate) is always "too late" and
// throws "It is too late to set compileSdk". A plain text patch before
// Gradle evaluates the project is the only reliable fix.
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
