package com.samuel.chirpy.core.network

import kotlinx.serialization.Serializable

@Serializable
internal data class ApiErrorDto(val error: Detail) {
    @Serializable
    data class Detail(val code: String, val message: String, val requestID: String? = null)
}
