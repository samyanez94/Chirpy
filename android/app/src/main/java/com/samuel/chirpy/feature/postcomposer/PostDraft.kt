package com.samuel.chirpy.feature.postcomposer

// Match ECMAScript trim and count Unicode code points, as the shared API does.
object PostDraft {
    const val MAX_CHARACTERS = 300

    fun trimmed(text: String): String = text.trim { char ->
        char in
            "\u0009\u000A\u000B\u000C\u000D\u0020\u00A0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF"
    }

    fun count(text: String): Int = trimmed(text).let { it.codePointCount(0, it.length) }

    fun isValid(text: String): Boolean = count(text) in 1..MAX_CHARACTERS
}
