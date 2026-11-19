allprojects {
    repositories {
        google()
        mavenCentral()
    }
    configurations.all {
        resolutionStrategy {
            force("com.google.android.gms:play-services-measurement:22.2.0")
            force("com.google.android.gms:play-services-measurement-api:22.2.0")
            force("com.google.android.gms:play-services-measurement-impl:22.2.0")
            force("com.google.android.gms:play-services-measurement-sdk:22.2.0")
            force("com.google.android.gms:play-services-measurement-sdk-api:22.2.0")
            force("com.google.android.gms:play-services-measurement-base:22.2.0")
        }
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
