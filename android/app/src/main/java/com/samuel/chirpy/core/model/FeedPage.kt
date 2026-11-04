package com.samuel.chirpy.core.model

data class FeedPage(val posts: List<Post>, val nextCursor: String?)
