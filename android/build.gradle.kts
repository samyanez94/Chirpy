plugins {
    `java-base`
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.compose) apply false
    alias(libs.plugins.serialization) apply false
}

// Isolated CLI runtimes avoid coupling analyzer compiler versions to AGP's built-in Kotlin.
val ktlintRuntime = configurations.create("ktlintRuntime")
val detektRuntime = configurations.create("detektRuntime")

dependencies {
    ktlintRuntime("com.pinterest.ktlint:ktlint-cli:${libs.versions.ktlint.get()}:all") {
        isTransitive = false
    }
    detektRuntime("io.gitlab.arturbosch.detekt:detekt-cli:${libs.versions.detekt.get()}:all") {
        isTransitive = false
    }
}

val qualityJava = javaToolchains.launcherFor {
    languageVersion.set(JavaLanguageVersion.of(17))
}

fun registerKtlintTask(name: String, fix: Boolean) = tasks.register<JavaExec>(name) {
    group = "verification"
    description =
        if (fix) "Format Kotlin sources and Gradle scripts." else "Check Kotlin formatting."
    javaLauncher.set(qualityJava)
    classpath = ktlintRuntime
    mainClass.set("com.pinterest.ktlint.Main")
    workingDir = rootDir
    if (fix) args("--format")
    args("**/*.kt", "**/*.kts", "!**/build/**", "!**/.gradle/**", "!**/.kotlin/**")
}

registerKtlintTask("ktlintCheck", false)
registerKtlintTask("ktlintFormat", true)

tasks.register<JavaExec>("detekt") {
    group = "verification"
    description = "Run stable detekt syntax analysis (without Kotlin 2.4 type resolution)."
    javaLauncher.set(qualityJava)
    classpath = detektRuntime
    mainClass.set("io.gitlab.arturbosch.detekt.cli.Main")
    workingDir = rootDir
    args(
        "--input",
        "app/src",
        "--config",
        "config/detekt.yml",
        "--report",
        "html:${layout.buildDirectory.file("reports/detekt/detekt.html").get().asFile}",
        "--report",
        "sarif:${layout.buildDirectory.file("reports/detekt/detekt.sarif").get().asFile}",
    )
}

tasks.register("format") {
    group = "formatting"
    dependsOn("ktlintFormat")
}

tasks.register("qualityCheck") {
    group = "verification"
    description = "Check formatting, Kotlin analysis, Android Lint, JVM tests, and the debug APK."
    dependsOn(
        "ktlintCheck",
        "detekt",
        ":app:lintDebug",
        ":app:lintRelease",
        ":app:testDebugUnitTest",
        ":app:assembleDebug",
    )
}

tasks.register("verify") {
    group = "verification"
    description = "Compatibility alias for qualityCheck."
    dependsOn("qualityCheck")
}

tasks.register("fullValidation") {
    group = "verification"
    description = "Run qualityCheck and verify the optimized release build."
    dependsOn("qualityCheck", ":app:assembleRelease")
}
