package com.michaeldeguzman.plugins.offlinebm25

import java.io.File

/** JVM fixture access. Reads tests/fixtures through the fixtures.dir system property set in build.gradle. */
object Fixtures {
    fun read(name: String): String =
        File(System.getProperty("fixtures.dir")!!, "$name.json").readText(Charsets.UTF_8)

    /** The .NET character data written by tools/charclass/run.sh, or null when absent. */
    fun charClassData(): String? {
        val file = File(System.getProperty("charclass.dir")!!, "dotnet.txt")
        return if (file.exists()) file.readText(Charsets.UTF_8) else null
    }

    fun tempDir(): File = java.nio.file.Files.createTempDirectory("bm25-tests").toFile()

    fun runtimeDescription(): String =
        "JVM ${System.getProperty("java.runtime.version")} ${System.getProperty("java.vendor")}"
}
