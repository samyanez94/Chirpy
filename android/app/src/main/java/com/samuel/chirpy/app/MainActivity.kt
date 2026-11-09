package com.samuel.chirpy.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.samuel.chirpy.core.ui.ChirpyTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val container = (application as ChirpyApplication).container
        setContent {
            ChirpyTheme {
                ChirpyAppRoot(container.socialRepository)
            }
        }
    }
}
