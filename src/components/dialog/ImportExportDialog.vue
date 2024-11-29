<template>
  <el-dialog
    v-model="dialogVisible"
    :title="isImport ? '导入数据' : '导出数据'"
    width="30%"
    draggable
  >
    <div class="import-export-content">
      <template v-if="isImport">
        <el-alert
          type="info"
          :closable="false"
          show-icon
        >
          <p>请选择要导入的JSON文件，或将数据粘贴到下方文本框中</p>
          <p>支持JSON格式的信用卡数据</p>
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
          :rows="8"
          placeholder="请粘贴JSON格式的信用卡数据"
        />
      </template>
      <template v-else>
        <el-alert
          type="success"
          :closable="false"
          show-icon
        >
          <p>已生成JSON格式的数据</p>
          <p>可以复制数据或下载为文件</p>
        </el-alert>
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
</template>

<script>
import { computed, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { CopyDocument, FolderOpened, Share } from '@element-plus/icons-vue'

export default {
  name: 'ImportExportDialog',
  components: {
    CopyDocument,
    FolderOpened,
    Share
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
    // 对话框可见性
    const dialogVisible = computed({
      get: () => props.visible,
      set: (value) => emit('update:visible', value)
    })

    // 导入文本
    const importText = ref('')
    // 导出文本
    const exportText = computed(() => {
      return JSON.stringify(props.data, null, 2)
    })

    // 检查JSON是否有效
    const isValidJson = computed(() => {
      try {
        if (!importText.value) return false
        const data = JSON.parse(importText.value)
        // 放宽数据验证条件，只要是数组且每项都是对象即可
        return Array.isArray(data) && data.every(item => 
          typeof item === 'object' && 
          item !== null
        )
      } catch {
        return false
      }
    })

    // 选中的文件名
    const selectedFile = ref('')

    // 监听对话框关闭，清空导入文本和文件名
    watch(dialogVisible, (newVal) => {
      if (!newVal) {
        importText.value = ''
        selectedFile.value = ''
      }
    })

    // 处理文件选择
    const handleFileChange = (file) => {
      if (file && file.raw) {
        const reader = new FileReader()
        reader.onload = (e) => {
          try {
            const data = JSON.parse(e.target.result)
            if (Array.isArray(data) && data.every(item => 
              typeof item === 'object' && 
              item !== null
            )) {
              importText.value = e.target.result
              selectedFile.value = file.name
            } else {
              ElMessage.error('文件格式错误，请选择有效的信用卡数据文件')
              selectedFile.value = ''
            }
          } catch {
            ElMessage.error('文件格式错误，请选择有效的JSON文件')
            selectedFile.value = ''
          }
        }
        reader.readAsText(file.raw)
      }
    }

    // 处理导入
    const handleImport = () => {
      try {
        const data = JSON.parse(importText.value)
        // 确保所有必需的字段都存在
        const template = {
          cardName: '',
          bankName: '',
          cardNumber: '',
          cardType: '',
          organization: '',
          creditLimit: '',
          billDay: '',
          repaymentDay: '',
          annualFee: '',
          cvv: '',
          validThru: ''
        }
        // 为缺失的字段添加默认值
        const processedData = data.map(item => ({
          ...template,
          ...item
        }))
        emit('import', processedData)
        dialogVisible.value = false
        ElMessage.success('数据导入成功')
      } catch (error) {
        ElMessage.error('数据格式错误，请检查后重试')
      }
    }

    // 处理取消
    const handleCancel = () => {
      dialogVisible.value = false
    }

    // 处理复制
    const handleCopy = async () => {
      try {
        await navigator.clipboard.writeText(exportText.value)
        ElMessage.success('已复制到剪贴板')
      } catch (error) {
        ElMessage.error('复制失败，请手动复制')
      }
    }

    // 处理下载
    const handleDownload = () => {
      const blob = new Blob([exportText.value], { type: 'application/json' })
      const url = window.URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = '信用卡数据.json'
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      window.URL.revokeObjectURL(url)
      ElMessage.success('文件下载成功')
    }

    return {
      dialogVisible,
      importText,
      exportText,
      isValidJson,
      selectedFile,
      handleImport,
      handleCancel,
      handleCopy,
      handleFileChange,
      handleDownload
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
  gap: 12px;
}

.file-name {
  color: var(--el-text-color-secondary);
  font-size: 14px;
}

.action-buttons {
  display: flex;
  justify-content: center;
  gap: 12px;
  margin-top: 8px;
}

:deep(.el-alert) {
  margin-bottom: 8px;
}

:deep(.el-alert__content) {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

:deep(.el-divider__text) {
  background-color: var(--el-bg-color);
}

.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

:deep(.el-textarea__inner) {
  font-family: monospace;
  font-size: 14px;
}

:deep(.el-upload) {
  width: auto;
}
</style>
