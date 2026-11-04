package com.samuel.chirpy.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.samuel.chirpy.core.ui.ChirpyTheme
import com.samuel.chirpy.feature.feed.FeedRoute
import com.samuel.chirpy.feature.feed.FeedViewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val container = (application as ChirpyApplication).container
        setContent {
            ChirpyTheme {
                val model: FeedViewModel =
                    viewModel(
                        factory =
                        viewModelFactory {
                            initializer { FeedViewModel(container.feedRepository) }
                        },
                    )
                FeedRoute(model)
            }
        }
    }
}
