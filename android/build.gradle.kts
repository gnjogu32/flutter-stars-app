import org.gradle.api.tasks.Delete

// Root build.gradle.kts

rootProject.layout.buildDirectory.value(rootProject.layout.projectDirectory.dir("../build"))

subprojects {
    project.layout.buildDirectory.value(rootProject.layout.buildDirectory.dir(project.name))
}

plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("com.google.firebase.appdistribution") version "5.0.0" apply false
}

allprojects {
    // FORCE APPLY KOTLIN PLUGIN (REQUIRED FOR AGP 9.2.1 COMPATIBILITY WITH LEGACY PLUGINS)
    if (project.name != "android") {
        plugins.withId("com.android.library") {
            if (!project.plugins.hasPlugin("kotlin-android") && 
                !project.plugins.hasPlugin("org.jetbrains.kotlin.android")) {
                println("FORCING kotlin-android on: ${project.name}")
                project.plugins.apply("kotlin-android")
            }
        }
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    afterEvaluate {
        if (project.extensions.findByName("android") != null) {
            val android = project.extensions.getByName("android")
            try {
                val method = android.javaClass.getMethod("setNdkVersion", String::class.java)
                method.invoke(android, "28.2.13676358")
            } catch (e: Exception) { }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
