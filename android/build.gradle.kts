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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// whisper_ggml 2.6.0 declares compileSdk 34, but its ffmpeg_kit dependency
// requires 35+. Lift every plugin to the app's compileSdk until upstream fixes it.
subprojects {
    val liftCompileSdk = Action<Project> {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                compileSdk = 36
            }
        }
    }
    // ":app" is already evaluated by the evaluationDependsOn block above.
    if (state.executed) liftCompileSdk.execute(this) else afterEvaluate(liftCompileSdk)
}
