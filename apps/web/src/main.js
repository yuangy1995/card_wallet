import './assets/main.scss'
import 'element-plus/es/components/message/style/css'
import 'element-plus/es/components/message-box/style/css'
import 'element-plus/es/components/notification/style/css'
import { createApp } from 'vue'
import VaultApp from './VaultApp.vue'
import { getAppName } from './utils/appName'
document.title = getAppName()
createApp(VaultApp).mount('#app')
