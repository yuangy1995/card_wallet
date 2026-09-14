package com.example.creditcard.ui.wallet

import com.example.creditcard.R

// Offline resources; sources and licenses are recorded in apps/android/branding.
internal object WalletBrandAssets {
    fun bank(bank: WalletBank): Int? = when (bank) {
        WalletBank.CMB -> R.drawable.wallet_bank_cmb
        WalletBank.BOC -> R.drawable.wallet_bank_boc
        WalletBank.ICBC -> R.drawable.wallet_bank_icbc
        WalletBank.ABC -> R.drawable.wallet_bank_abc
        WalletBank.CCB -> R.drawable.wallet_bank_ccb
        WalletBank.BOCOM -> R.drawable.wallet_bank_bocom
        WalletBank.CITIC -> R.drawable.wallet_bank_citic
        WalletBank.CGB -> R.drawable.wallet_bank_cgb
        WalletBank.PINGAN -> R.drawable.wallet_bank_pingan
        WalletBank.SPDB -> R.drawable.wallet_bank_spdb
        WalletBank.CIB -> R.drawable.wallet_bank_cib
        WalletBank.CEB -> R.drawable.wallet_bank_ceb
        WalletBank.CMBC -> R.drawable.wallet_bank_cmbc
        WalletBank.PSBC -> R.drawable.wallet_bank_psbc
        WalletBank.HXB -> R.drawable.wallet_bank_hxb
        WalletBank.HSBC -> R.drawable.wallet_bank_hsbc
        WalletBank.BOA -> R.drawable.wallet_bank_boa
        WalletBank.CITI -> R.drawable.wallet_bank_citi
        WalletBank.SC -> R.drawable.wallet_bank_sc
        WalletBank.HANGSENG -> R.drawable.wallet_bank_hangseng
        WalletBank.DBS -> R.drawable.wallet_bank_dbs
        WalletBank.AMEX -> R.drawable.wallet_network_amex
        else -> null
    }

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
