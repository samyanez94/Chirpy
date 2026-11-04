package com.samuel.chirpy.core.data

class ApiException(val code: String, val status: Int, val requestId: String?) : Exception(code)
