<template>
  <el-config-provider :locale="zhCn">
    <WalletApp v-if="ready && unlocked" />
    <main v-else class="vault-entry">
      <h1>卡包</h1>
      <p v-if="!ready && !error">正在打开本地保险库…</p>
      <template v-if="error">
        <p role="alert">{{ error }}</p>
        <el-button @click="boot">重试</el-button>
      </template>
      <p v-else-if="ready">卡片与同步凭证使用本地密码加密。请妥善保存密码。</p>
      <PasswordVerify v-if="ready && passwordExists" :model-value="true" @verified="openWallet" @forgot-password="resetVault" />
      <PasswordSetup v-if="ready && !passwordExists" :model-value="true" @password-set="openWallet" />
    </main>
  </el-config-provider>
</template>

<script setup>
import { ref, defineAsyncComponent, onMounted, onUnmounted, provide } from 'vue'
import { ElMessage, ElMessageBox, ElNotification } from 'element-plus'
import zhCn from 'element-plus/dist/locale/zh-cn.mjs'
import { localDataStore } from './utils/indexedDbStorage'
import { PasswordManager } from './utils/passwordManager'
import { useTheme } from './composables/useTheme'
import { useCalendarDay } from './composables/useCalendarDay'
const WalletApp = defineAsyncComponent(() => import('./App.vue'))
const PasswordVerify = defineAsyncComponent(() => import('./components/security/PasswordVerify.vue'))
const PasswordSetup = defineAsyncComponent(() => import('./components/security/PasswordSetup.vue'))
provide('theme', useTheme())
provide('calendarDay', useCalendarDay())
const ready = ref(false)
const unlocked = ref(false)
const passwordExists = ref(false)
const error = ref('')
const boot = async () => {
  ready.value = false
  error.value = ''
  try {
    await localDataStore.initialize()
    passwordExists.value = PasswordManager.hasPassword()
    ready.value = true
  } catch (failure) { error.value = failure.message }
}
const openWallet = () => {
  if (!localDataStore.isUnlocked) return
  PasswordManager.unlockApp()
  passwordExists.value = true
  unlocked.value = true
}
const onLock = () => {
  unlocked.value = false
  passwordExists.value = PasswordManager.hasPassword()
  ElMessageBox.close()
  ElMessage.closeAll()
  ElNotification.closeAll()
}
const resetVault = async () => {
  try {
    await ElMessageBox.confirm(
      '本地密码无法找回。重置会删除此浏览器中的卡片、同步凭证和历史，不会删除云端备份。重置后需要重新设置本地密码，再手动填写 WebDAV 账号和原同步密钥恢复云端数据。确定重置？',
      '重置本地保险库', { type: 'warning', confirmButtonText: '删除本地数据并重置', cancelButtonText: '取消', zIndex: 200010 }
    )
    if (!(await PasswordManager.clearAllAppData())) throw new Error('本地数据未能完整清除，请重试。')
    passwordExists.value = false
    unlocked.value = false
  } catch (failure) {
    if (failure instanceof Error) ElMessage.error({ message: failure.message, zIndex: 200010 })
  }
}
const onPageHide = () => { if (unlocked.value) PasswordManager.lockApp() }
onMounted(() => {
  window.addEventListener('wallet-vault-locked', onLock)
  window.addEventListener('pagehide', onPageHide)
  boot()
})
onUnmounted(() => {
  window.removeEventListener('wallet-vault-locked', onLock)
  window.removeEventListener('pagehide', onPageHide)
})
</script>

<style scoped>
.vault-entry { min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 24px; color: var(--el-text-color-primary); background: var(--el-bg-color-page); }
.vault-entry p { max-width: 36rem; text-align: center; line-height: 1.8; color: var(--el-text-color-secondary); }
</style>
