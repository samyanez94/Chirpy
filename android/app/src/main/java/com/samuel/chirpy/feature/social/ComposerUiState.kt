package com.samuel.chirpy.feature.social

data class ComposerUiState(
    val draft: String = "",
    val isPosting: Boolean = false,
    val hasFailed: Boolean = false,
) {
    val characterCount: Int = PostDraft.count(draft)
    val characterLimit: Int = PostDraft.MAX_CHARACTERS
    val isOverLimit: Boolean = characterCount > characterLimit
    val canPublish: Boolean = !isPosting && characterCount in 1..characterLimit
}
