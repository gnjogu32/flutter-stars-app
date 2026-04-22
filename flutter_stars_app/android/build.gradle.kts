allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Custom build directory override removed to restore standard Flutter APK output path.
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
