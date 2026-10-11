package com.nova.sync.player

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.nova.sync.data.Channel
import com.nova.sync.data.FavoritesStore
import com.nova.sync.data.Repository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ChannelsUiState(
    val loading: Boolean = true,
    val error: String? = null,
    val channels: List<Channel> = emptyList(),
    val favorites: Set<String> = emptySet(),
)

class ChannelsViewModel : ViewModel() {
    private val _state = MutableStateFlow(ChannelsUiState())
    val state: StateFlow<ChannelsUiState> = _state.asStateFlow()

    init { load() }

    fun load() {
        _state.value = _state.value.copy(loading = true, error = null)
        viewModelScope.launch {
            Repository.loadCatalog()
                .onSuccess { cat ->
                    _state.value = ChannelsUiState(
                        loading = false,
                        channels = cat.channels,
                        favorites = FavoritesStore.all(),
                    )
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(
                        loading = false,
                        error = e.message ?: "error",
                    )
                }
        }
    }

    fun toggleFavorite(id: String) {
        val favs = FavoritesStore.toggle(id)
        _state.value = _state.value.copy(favorites = favs)
    }
}
