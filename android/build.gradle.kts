allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Standard build directory layout
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
