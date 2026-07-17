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

// maps_launcher (latest published version, 3.0.0+1) hardcodes compileSdkVersion 33,
// which is too old for its own androidx transitive deps (they require 34+). No newer
// fixed release exists on pub.dev, so force a higher compileSdk here. `:app` is excluded
// since evaluationDependsOn(":app") above already fully evaluates it before this block
// runs, and afterEvaluate can't be registered on an already-evaluated project.
subprojects {
    if (project.name == "app") return@subprojects
    afterEvaluate {
        val androidExt = project.extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            if (androidExt.compileSdkVersion?.removePrefix("android-")?.toIntOrNull()
                    ?.let { it < 34 } == true
            ) {
                androidExt.compileSdkVersion("android-34")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
