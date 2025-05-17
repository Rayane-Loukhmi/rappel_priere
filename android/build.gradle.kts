buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.6.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:none")
        options.compilerArgs.add("-Xlint:-options")
    }

    afterEvaluate {
        if (project.name == "shared_preferences_android") {
            apply(from = rootProject.file("shared_preferences_android.gradle"))
        }
    }
}

rootProject.layout.buildDirectory.set(rootProject.projectDir.resolve("../build"))
subprojects {
    project.layout.buildDirectory.set(rootProject.layout.buildDirectory.get().dir(project.name))
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}

plugins {
    id("com.google.gms.google-services") version "4.4.0" apply false
}
