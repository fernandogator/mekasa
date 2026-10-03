package app.mekasa.fable.session

import android.content.Context

/** Remembers the last signed-in email so Welcome can prefill it after sign-out (REQ-022 AC5). */
interface EmailMemory {
    fun load(): String?
    fun save(email: String?)
}

class InMemoryEmailMemory(private var value: String? = null) : EmailMemory {
    override fun load(): String? = value
    override fun save(email: String?) {
        value = email
    }
}

class PrefsEmailMemory(context: Context) : EmailMemory {
    private val prefs = context.applicationContext.getSharedPreferences("mekasa_fable_session", Context.MODE_PRIVATE)

    override fun load(): String? = prefs.getString(KEY, null)?.takeIf { it.isNotBlank() }

    override fun save(email: String?) {
        prefs.edit().apply {
            if (email.isNullOrBlank()) remove(KEY) else putString(KEY, email)
        }.apply()
    }

    private companion object {
        const val KEY = "last_email"
    }
}
