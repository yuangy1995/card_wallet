<template>
  <span class="wallet-brand-mark" :class="{ 'on-card': onCard }" :data-resource="resource || 'wallet-bank-fallback'">
    <img v-if="resource && !failed" :src="source" :alt="label" :class="{ 'white-mark': whiteMark }"
      loading="lazy" decoding="async" draggable="false" @error="failed = true" />
    <svg v-else viewBox="0 0 32 24" role="img" aria-label="银行卡" fill="none" stroke="currentColor" stroke-width="1.8">
      <rect x="2" y="3" width="28" height="18" rx="3" /><path d="M2 9h28M6 16h7" />
    </svg>
  </span>
</template>
<script setup>
import { computed, ref, watch, inject, unref } from 'vue'
import { matchIssuer } from '../../utils/walletLogoCatalog'
const props = defineProps({ bank: { type: String, default: '' }, country: { type: String, default: '' },
  network: { type: String, default: '' }, onCard: Boolean })
const failed = ref(false)
const theme = inject('theme', null)
const dark = computed(() => Boolean(unref(theme?.isDarkMode)))
const networks = { visa: 'Visa', mastercard: 'Mastercard', amex: 'American Express', unionpay: 'UnionPay',
  jcb: 'JCB', discover: 'Discover', diners: 'Diners Club' }
const issuer = computed(() => props.network ? null : matchIssuer(props.bank, props.country))
const resource = computed(() => props.network
  ? (Object.hasOwn(networks, props.network) ? `wallet_network_${props.network}` : null)
  : issuer.value ? `${issuer.value.resource}${props.onCard || dark.value ? '_card' : ''}` : null)
const label = computed(() => props.network ? networks[props.network] || '银行卡' : issuer.value?.name || '银行卡')
const source = computed(() => resource.value ? `${import.meta.env.BASE_URL}wallet-brands/${resource.value}.webp` : '')
const whiteMark = computed(() => (props.onCard || dark.value) && ['visa', 'amex'].includes(props.network))
watch(source, () => { failed.value = false })
</script>
<style scoped>
.wallet-brand-mark { display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0;
  width: 36px; height: 28px; vertical-align: middle; color: var(--el-text-color-secondary); }
.wallet-brand-mark img, .wallet-brand-mark svg { display: block; width: 100%; height: 100%; object-fit: contain; }
.wallet-brand-mark.on-card { color: rgba(255, 255, 255, .9); }
.wallet-brand-mark img.white-mark { filter: brightness(0) invert(1); opacity: .9; }
</style>
