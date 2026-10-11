package com.nova.sync

import android.app.Application
import com.nova.sync.data.FavoritesStore
import com.nova.sync.data.HistoryStore

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        FavoritesStore.init(this)
        HistoryStore.init(this)
        SignatureGuard.init(this)
    }
}
