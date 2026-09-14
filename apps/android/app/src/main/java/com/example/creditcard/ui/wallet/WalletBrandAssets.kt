package com.example.creditcard.ui.wallet

import com.example.creditcard.R

internal object WalletBrandAssets {
    fun network(network: WalletNetwork): Int? = when (network) {
        WalletNetwork.VISA -> R.drawable.wallet_network_visa
        WalletNetwork.MASTERCARD -> R.drawable.wallet_network_mastercard
        WalletNetwork.AMEX -> R.drawable.wallet_network_amex
        WalletNetwork.UNIONPAY -> R.drawable.wallet_network_unionpay
        WalletNetwork.JCB -> R.drawable.wallet_network_jcb
        WalletNetwork.DISCOVER -> R.drawable.wallet_network_discover
        WalletNetwork.DINERS -> R.drawable.wallet_network_diners
        else -> null
    }
}
