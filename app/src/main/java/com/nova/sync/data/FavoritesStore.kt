package com.nova.sync.data

import android.content.Context
import android.content.SharedPreferences

object FavoritesStore {
    private lateinit var prefs: SharedPreferences
    fun init(ctx: Context) {
        prefs = ctx.getSharedPreferences("f", Context.MODE_PRIVATE)
    }
    fun all(): Set<String> = prefs.getStringSet("f", emptySet()) ?: emptySet()
    fun toggle(id: String): Set<String> {
        val s = all().toMutableSet()
        if (!s.add(id)) s.remove(id)
        prefs.edit().putStringSet("f", s).apply()
        return s
    }
}
