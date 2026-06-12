package com.example.creditcard.utils

private val bankParenthesesPattern = Regex("\\s*[（(][^（）()]*[）)]\\s*")
private val whitespacePattern = Regex("\\s+")

fun displayBankName(value: String?): String = value.orEmpty().trim()

fun normalizeBankNameForMatch(value: String?): String {
    return displayBankName(value)
        .replace(bankParenthesesPattern, "")
        .replace(whitespacePattern, "")
        .trim()
}

fun bankNamesReferToSameBank(left: String?, right: String?): Boolean {
    val leftDisplay = displayBankName(left)
    val rightDisplay = displayBankName(right)
    if (leftDisplay.isBlank() || rightDisplay.isBlank()) return false
    if (leftDisplay == rightDisplay) return true

    val leftKey = normalizeBankNameForMatch(leftDisplay)
    val rightKey = normalizeBankNameForMatch(rightDisplay)
    return leftKey.isNotBlank() && rightKey.isNotBlank() && leftKey == rightKey
}

fun shouldPropagateBankRename(previousBank: String?, nextBank: String?): Boolean {
    val previousDisplay = displayBankName(previousBank)
    val nextDisplay = displayBankName(nextBank)
    return previousDisplay.isNotBlank() && nextDisplay.isNotBlank() && previousDisplay != nextDisplay
}
