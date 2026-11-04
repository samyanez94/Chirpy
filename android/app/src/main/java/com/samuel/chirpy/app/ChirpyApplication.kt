package com.samuel.chirpy.app

import android.app.Application

class ChirpyApplication : Application() {
    val container by lazy { AppContainer() }
}
