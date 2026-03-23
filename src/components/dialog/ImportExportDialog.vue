<template>
  <div>
    <export-password-dialog
      v-if="showPasswordDialog"
      v-model:visible="showPasswordDialog"
      @confirm="handlePasswordConfirm"
      @skip="handlePasswordSkip"
    />
    
    <el-dialog
      v-model="dialogVisible"
      :title="isImport ? '导入数据' : '导出数据'"
      width="30%"
      draggable
      :before-close="handleClose"
    >
    <div class="import-export-content">
      <template v-if="isImport">
        <el-alert
          type="info"
          :closable="false"
          show-icon
        >
          <p>请选择要导入的加密数据文件，或将加密数据粘贴到下方文本框中</p>
          <p>如果数据已加密，请输入解密密码</p>
        </el-alert>
        <div class="file-upload">
          <el-upload
            class="upload-demo"
            action=""
            :auto-upload="false"
            :show-file-list="false"
            accept=".json"
            :on-change="handleFileChange"
          >
            <template #trigger>
              <el-button type="primary">
                <el-icon><FolderOpened /></el-icon>
                选择文件
              </el-button>
            </template>
          </el-upload>
          <span v-if="selectedFile" class="file-name">
            已选择: {{ selectedFile }}
          </span>
        </div>
        <el-divider>或</el-divider>
        <el-input
          v-model="importText"
          type="textarea"
          :rows="6"
          placeholder="请粘贴加密的数据"
        />
        <el-input
          v-if="showPasswordInput"
          v-model="password"
          type="password"
          placeholder="请输入解密密码"
          show-password
          class="password-input"
        />
      </template>
      <template v-else>
        <el-input
          v-model="exportText"
          type="textarea"
          :rows="8"
          readonly
        />
        <div class="action-buttons">
          <el-button type="primary" @click="handleCopy">
            <el-icon><CopyDocument /></el-icon>
            复制到剪贴板
          </el-button>
          <el-button type="success" @click="handleDownload">
            <el-icon><Share /></el-icon>
            下载文件
          </el-button>
          <!-- 仅在开发测试环境显示明文导出按钮 -->
          <el-button 
            v-if="isDevelopment" 
            type="warning" 
            @click="handlePlaintextExport"
          >
            <el-icon><DocumentCopy /></el-icon>
            导出明文数据
          </el-button>
          <el-button
            v-if="isDevelopment"
            type="info"
            @click="handlePrivacyPlaintextExport"
          >
            <el-icon><DocumentCopy /></el-icon>
            隐私导出明文数据
          </el-button>
        </div>
      </template>
    </div>

    <template #footer>
      <span class="dialog-footer">
        <el-button @click="handleCancel">取消</el-button>
        <el-button 
          v-if="isImport"
          type="primary" 
          @click="handleImport"
          :disabled="!isValidJson"
        >
          导入
        </el-button>
      </span>
    </template>
    </el-dialog>
  </div>
</template>

<script>
import { computed, ref, watch, inject } from 'vue'
import { ElMessage } from 'element-plus'
import { CopyDocument, FolderOpened, Share, DocumentCopy } from '@element-plus/icons-vue'
import { encryptData, decryptData } from '../../utils/encryption'
import ExportPasswordDialog from './ExportPasswordDialog.vue'
import { useAutoLock } from '@/composables/useAutoLock'

export default {
  name: 'ImportExportDialog',
  components: {
    CopyDocument,
    FolderOpened,
    Share,
    DocumentCopy,
    ExportPasswordDialog
  },
  props: {
    visible: {
      type: Boolean,
      required: true
    },
    isImport: {
      type: Boolean,
      required: true
    },
    data: {
      type: Array,
      default: () => []
    }
  },
  emits: ['update:visible', 'import'],
  setup(props, { emit }) {
    const showPasswordDialog = ref(false)
    const password = ref('')
    const tempData = ref(null)
    const providedAutoLock = inject('autoLock', null)
    const { isLocked } = providedAutoLock || useAutoLock()
    
    // 检测是否为开发环境
    const isDevelopment = computed(() => {
      return import.meta.env.MODE === 'development' || 
             import.meta.env.DEV === true ||
             window.location.hostname === 'localhost' ||
             window.location.hostname === '127.0.0.1'
    })
    
    // 对话框可见性
    const dialogVisible = computed({
      get: () => props.visible && (!props.isImport ? !!tempData.value : true),
      set: (value) => {
        if (!value) {
          emit('update:visible', false)
          tempData.value = null
        }
      }
    })

    watch(() => props.visible, (newVal) => {
      if (newVal && !props.isImport) {
        showPasswordDialog.value = true
      }
    })

    // 导入文本
    const importText = ref('')
    // 导出文本
    const exportText = computed(() => {
      if (!tempData.value) return ''
      try {
        return tempData.value
      } catch (error) {
        ElMessage.error(error.message)
        return ''
      }
    })

    // 检查导入数据是否有效
    const isValidJson = computed(() => {
      if (!importText.value) return false
      
      // 检查是否是加密数据
      if (importText.value.startsWith('encrypted:')) {
        // 自定义密码加密的数据需要输入密码
        return !!password.value
      } else if (importText.value.startsWith('default:')) {
        // 默认密码加密的数据不需要验证
        return true
      }
      
      // 尝试作为普通JSON解析
      try {
        const data = JSON.parse(importText.value)
        return Array.isArray(data) && data.every(item => 
          typeof item === 'object' && 
          item !== null
        )
      } catch {
        return false
      }
    })

    // 是否需要显示密码输入框
    const showPasswordInput = computed(() => {
      return importText.value?.startsWith('encrypted:')
    })

    // 选中的文件名
    const selectedFile = ref('')

    watch(isLocked, (locked) => {
      if (locked) {
        showPasswordDialog.value = false
        emit('update:visible', false)
        tempData.value = null
        importText.value = ''
        password.value = ''
        selectedFile.value = ''
      }
    })

    // 监听对话框关闭，清空导入文本和文件名
    watch(dialogVisible, (newVal) => {
      if (!newVal) {
        importText.value = ''
        selectedFile.value = ''
        password.value = ''
        tempData.value = null
      }
    })

    const handlePasswordConfirm = (pwd) => {
      const encrypted = encryptData(props.data, pwd)
      tempData.value = encrypted
    }

    const handlePasswordSkip = () => {
      const encrypted = encryptData(props.data)
      tempData.value = encrypted
    }

    const getCrypto = () => {
      return window.crypto || globalThis.crypto
    }

    const getRandomDigit = () => {
      const cryptoApi = getCrypto()
      if (!cryptoApi?.getRandomValues) {
        return Math.floor(Math.random() * 10)
      }
      const array = new Uint32Array(1)
      cryptoApi.getRandomValues(array)
      return array[0] % 10
    }

    const randomDigits = (length, { firstDigit } = {}) => {
      if (!length || length <= 0) return ''
      let result = ''
      for (let index = 0; index < length; index += 1) {
        if (index === 0 && firstDigit !== undefined && firstDigit !== null) {
          result += String(firstDigit)
          continue
        }
        result += String(getRandomDigit())
      }
      return result
    }

    const randomFutureValid = () => {
      const month = String((getRandomDigit() % 12) + 1).padStart(2, '0')
      const yearOffset = (getRandomDigit() % 8) + 1
      const year = String((new Date().getFullYear() + yearOffset) % 100).padStart(2, '0')
      return `${month}/${year}`
    }

    const sanitizeCardNumber = (value) => {
      if (!value) return value
      const rawValue = String(value)
      const digitsOnly = rawValue.replace(/\D/g, '')
      if (!digitsOnly) return value
      const firstDigit = digitsOnly[0]
      const randomizedDigits = randomDigits(digitsOnly.length, { firstDigit })

      if (/\s/.test(rawValue)) {
        const groups = randomizedDigits.match(/\d{1,4}/g)
        return groups ? groups.join(' ') : randomizedDigits
      }
      return randomizedDigits
    }

    const sanitizeCvv = (value) => {
      if (!value) return value
      const rawValue = String(value)
      const digitsOnly = rawValue.replace(/\D/g, '')
      return digitsOnly ? randomDigits(digitsOnly.length) : value
    }

    const sanitizeSensitiveCardData = (card) => {
      const sanitizedCard = { ...card }

      if (Object.prototype.hasOwnProperty.call(sanitizedCard, 'cardNumber')) {
        sanitizedCard.cardNumber = sanitizeCardNumber(sanitizedCard.cardNumber)
      }

      if (Object.prototype.hasOwnProperty.call(sanitizedCard, 'cvv')) {
        sanitizedCard.cvv = sanitizeCvv(sanitizedCard.cvv)
      }

      if (Object.prototype.hasOwnProperty.call(sanitizedCard, 'valid') && sanitizedCard.valid) {
        sanitizedCard.valid = randomFutureValid()
      }

      return sanitizedCard
    }

    const downloadJsonFile = (content, filename) => {
      const blob = new Blob([content], { type: 'application/json' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = filename
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)
    }

    // 处理文件选择
    const handleFileChange = (file) => {
      if (file && file.raw) {
        const reader = new FileReader()
        reader.onload = (e) => {
          try {
            importText.value = e.target.result.trim()
            selectedFile.value = file.name
          } catch {
            ElMessage.error('文件读取失败')
            selectedFile.value = ''
          }
        }
        reader.readAsText(file.raw)
      }
    }

    // 处理导入
    const handleImport = () => {
      if (!importText.value) {
        ElMessage.error('请输入要导入的数据')
        return
      }

      try {
        let data
        if (importText.value.startsWith('encrypted:')) {
          // 自定义密码加密的数据
          if (!password.value) {
            ElMessage.error('请输入解密密码')
            return
          }
          try {
            data = decryptData(importText.value, password.value)
          } catch (error) {
            if (error.message.includes('请输入解密密码')) {
              ElMessage.error('请输入解密密码')
            } else {
              ElMessage.error('密码错误，请重试')
            }
            return
          }
        } else if (importText.value.startsWith('default:')) {
          // 默认密码加密的数据
          try {
            data = decryptData(importText.value)
          } catch (error) {
            ElMessage.error('数据解密失败')
            return
          }
        } else {
          // 未加密的数据
          try {
            data = JSON.parse(importText.value)
          } catch {
            ElMessage.error('数据格式错误，请检查是否为有效的JSON格式')
            return
          }
        }

        if (!Array.isArray(data)) {
          ElMessage.error('数据格式错误，请确保导入的是信用卡数据列表')
          return
        }

        if (!data.every(item => typeof item === 'object' && item !== null)) {
          ElMessage.error('数据格式错误，请确保每条数据都是有效的信用卡信息')
          return
        }

        emit('import', data)
        dialogVisible.value = false
        // 不显示导入成功消息，避免与其他导入消息重复
      } catch (error) {
        ElMessage.error('导入失败：' + error.message)
      }
    }

    // 复制到剪贴板
    const handleCopy = async () => {
      try {
        await navigator.clipboard.writeText(exportText.value)
        ElMessage.success('已复制到剪贴板')
      } catch (error) {
        ElMessage.error('复制失败')
      }
    }

    // 下载文件
    const handleDownload = () => {
      downloadJsonFile(
        exportText.value,
        `credit_cards_${new Date().toISOString().split('T')[0]}.json`
      )
    }

    // 导出明文数据（仅开发环境）
    const handlePlaintextExport = () => {
      if (!isDevelopment.value) {
        ElMessage.warning('明文导出功能仅在开发环境下可用')
        return
      }
      
      try {
        const plaintextData = JSON.stringify(props.data, null, 2)
        downloadJsonFile(
          plaintextData,
          `credit_cards_plaintext_${new Date().toISOString().split('T')[0]}.json`
        )
        ElMessage.success('明文数据导出成功')
      } catch (error) {
        ElMessage.error('明文数据导出失败：' + error.message)
      }
    }

    // 隐私导出明文数据（仅开发环境）
    const handlePrivacyPlaintextExport = () => {
      if (!isDevelopment.value) {
        ElMessage.warning('隐私导出功能仅在开发环境下可用')
        return
      }

      try {
        const sanitizedData = props.data.map(item => sanitizeSensitiveCardData(item))
        const plaintextData = JSON.stringify(sanitizedData, null, 2)
        downloadJsonFile(
          plaintextData,
          `credit_cards_private_plaintext_${new Date().toISOString().split('T')[0]}.json`
        )
        ElMessage.success('隐私明文数据导出成功')
      } catch (error) {
        ElMessage.error('隐私明文数据导出失败：' + error.message)
      }
    }

    // 取消
    const handleCancel = () => {
      dialogVisible.value = false
    }

    const handleClose = () => {
      dialogVisible.value = false
    }

    return {
      dialogVisible,
      showPasswordDialog,
      importText,
      exportText,
      selectedFile,
      password,
      isValidJson,
      showPasswordInput,
      isDevelopment,
      handleFileChange,
      handleImport,
      handleCopy,
      handleDownload,
      handlePlaintextExport,
      handlePrivacyPlaintextExport,
      handleCancel,
      handlePasswordConfirm,
      handlePasswordSkip,
      handleClose
    }
  }
}
</script>

<style scoped>
.import-export-content {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.file-upload {
  display: flex;
  align-items: center;
  gap: 16px;
}

.file-name {
  color: #606266;
}

.action-buttons {
  display: flex;
  gap: 16px;
  margin-top: 16px;
}

.password-input {
  margin: 16px 0;
}

:deep(.el-alert) {
  margin-bottom: 16px;
}

:deep(.el-textarea__inner) {
  font-family: monospace;
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}
</style>
