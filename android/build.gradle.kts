import org.gradle.api.tasks.Delete

// Root build.gradle.kts

rootProject.layout.buildDirectory.value(rootProject.layout.projectDirectory.dir("../build"))

subprojects {
    project.layout.buildDirectory.value(rootProject.layout.buildDirectory.dir(project.name))
}

plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
    id("com.google.firebase.appdistribution") version "5.2.1" apply false
}

allprojects {
    // FORCE APPLY KOTLIN PLUGIN (REQUIRED FOR AGP 9.2.1 COMPATIBILITY)
    if (project.name != "android") {
        plugins.withId("com.android.library") {
            if (!project.plugins.hasPlugin("kotlin-android") && 
                !project.plugins.hasPlugin("org.jetbrains.kotlin.android")) {
                println("FORCING kotlin-android on: ${project.name}")
                project.plugins.apply("kotlin-android")
            }
        }
        plugins.withId("com.android.application") {
            if (!project.plugins.hasPlugin("kotlin-android") && 
                !project.plugins.hasPlugin("org.jetbrains.kotlin.android")) {
                println("FORCING kotlin-android on: ${project.name}")
                project.plugins.apply("kotlin-android")
            }
        }
    }

    // ENFORCE JVM TARGET 17 FOR ALL COMPILATION TASKS
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    afterEvaluate {
        // Enforce NDK version across all subprojects using reflection as mentioned in README.md
        if (project.extensions.findByName("android") != null) {
            val android = project.extensions.getByName("android")
            try {
                val method = android.javaClass.getMethod("setNdkVersion", String::class.java)
                method.invoke(android, "28.2.13676358")
            } catch (e: Exception) {
                // Ignore reflection errors
            }

            try {
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                val setSource = compileOptions.javaClass.getMethod("setSourceCompatibility", Object::class.java)
                val setTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", Object::class.java)
                // Use "17" as string which Gradle/AGP converts to JavaVersion.VERSION_17
                setSource.invoke(compileOptions, "17")
                setTarget.invoke(compileOptions, "17")
            } catch (e: Exception) {
                // Ignore reflection errors
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
