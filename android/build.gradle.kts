allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Set the build directory to the standard Flutter location (root_project/build)
val rootBuildDir = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(rootBuildDir)

subprojects {
    val subprojectBuildDir = rootBuildDir.dir(project.name)
    project.layout.buildDirectory.value(subprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Removed afterEvaluate block to fix Gradle build error

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
