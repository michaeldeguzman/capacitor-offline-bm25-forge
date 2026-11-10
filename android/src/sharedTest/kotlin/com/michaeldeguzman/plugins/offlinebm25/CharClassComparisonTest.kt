package com.michaeldeguzman.plugins.offlinebm25

import org.junit.Assume.assumeNotNull
import org.junit.Test

/**
 * Compares CharRules with the .NET data file for all 65,536 UTF-16 code units and prints the
 * differences as ranges. The data file comes from tools/charclass/run.sh. Without it, the test
 * is skipped. This reports differences. It does not assert on them, because the differences
 * depend on the runtime's Unicode version and are documented in docs/charclass-comparison.md.
 * Output lines start with CHARCLASS| so run.sh can collect them.
 */
class CharClassComparisonTest {
    private class Run(val rule: String, val first: Int, var last: Int, val dotnet: String, val actual: String)

    @Test
    fun compareAllCodeUnitsWithDotNet() {
        val data = Fixtures.charClassData()
        assumeNotNull(data)
        val lines = data!!.split('\n').filter { it.isNotEmpty() }
        val runs = ArrayList<Run>()
        val open = HashMap<String, Run>()
        var rows = 0

        fun record(rule: String, unit: Int, dotnet: String, actual: String) {
            val current = open[rule]
            if (dotnet == actual) {
                open.remove(rule)
                return
            }
            if (current != null && current.last == unit - 1 && current.dotnet == dotnet && current.actual == actual) {
                current.last = unit
            } else {
                val run = Run(rule, unit, unit, dotnet, actual)
                runs.add(run)
                open[rule] = run
            }
        }

        for (line in lines.drop(1)) {
            val f = line.split(' ')
            val unit = f[0].toInt(16)
            val c = unit.toChar()
            rows++
            record("IsLetterOrDigit", unit, (f[1] == "1").toString(), CharRules.isLetterOrDigit(c).toString())
            record("IsWhiteSpace", unit, (f[2] == "1").toString(), CharRules.isWhiteSpace(c).toString())
            record("IsDigit", unit, (f[3] == "1").toString(), CharRules.isDigit(c).toString())
            record("ToLowerInvariant", unit, hex(f[4].toInt(16)), hex(CharRules.lowercase(c).code))
        }

        println("CHARCLASS|runtime|${Fixtures.runtimeDescription()}")
        println("CHARCLASS|dotnet|${lines.first().removePrefix("# ")}")
        println("CHARCLASS|units|$rows")
        val perRule = runs.groupBy { it.rule }
        for (rule in listOf("IsLetterOrDigit", "IsWhiteSpace", "IsDigit", "ToLowerInvariant")) {
            val ruleRuns = perRule[rule].orEmpty()
            println("CHARCLASS|total|$rule|${ruleRuns.sumOf { it.last - it.first + 1 }}")
        }
        for (run in runs) {
            println("CHARCLASS|diff|${run.rule}|${hex(run.first)}|${hex(run.last)}|${run.last - run.first + 1}|${run.dotnet}|${run.actual}")
        }
        println("CHARCLASS|end")
    }

    private fun hex(v: Int) = "U+" + v.toString(16).uppercase().padStart(4, '0')
}
