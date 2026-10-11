package com.nova.sync.data

import android.content.Context
import android.content.SharedPreferences

object HistoryStore {
    private lateinit var prefs: SharedPreferences
    fun init(ctx: Context) {
        prefs = ctx.getSharedPreferences("h", Context.MODE_PRIVATE)
    }
    fun all(): List<String> =
        prefs.getString("h", "").orEmpty().split(",").filter { it.isNotBlank() }
    fun push(id: String) {
        val l = all().toMutableList()
        l.remove(id); l.add(0, id)
        prefs.edit().putString("h", l.take(50).joinToString(",")).apply()
    }
}
