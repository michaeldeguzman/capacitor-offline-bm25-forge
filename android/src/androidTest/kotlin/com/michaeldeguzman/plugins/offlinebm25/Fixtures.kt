package com.michaeldeguzman.plugins.offlinebm25

import android.os.Build
import androidx.test.platform.app.InstrumentationRegistry

/** Emulator fixture access. tests/fixtures is added as androidTest assets in build.gradle, not copied. */
object Fixtures {
    private fun assets() = InstrumentationRegistry.getInstrumentation().context.assets

    fun read(name: String): String =
        assets().open("$name.json").bufferedReader(Charsets.UTF_8).use { it.readText() }

    /** The .NET character data written by tools/charclass/run.sh, or null when absent. */
    fun charClassData(): String? = try {
        assets().open("dotnet.txt").bufferedReader(Charsets.UTF_8).use { it.readText() }
    } catch (e: java.io.IOException) {
        null
    }

    fun tempDir(): java.io.File {
        val base = InstrumentationRegistry.getInstrumentation().targetContext.cacheDir
        return java.io.File(base, "bm25-tests-" + java.util.UUID.randomUUID()).also { it.mkdirs() }
    }

    fun runtimeDescription(): String =
        "Android API ${Build.VERSION.SDK_INT} ${Build.MANUFACTURER} ${Build.MODEL} ${Build.SUPPORTED_ABIS.first()}"
}
