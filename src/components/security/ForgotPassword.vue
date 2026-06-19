<template>
  <el-dialog
    v-model="visible"
    title="忘记密码"
    width="450px"
    :close-on-click-modal="false"
    :z-index="200001"
    center
  >
    <div class="forgot-password">
      <el-alert
        title="选择重置方式"
        type="warning"
        :closable="false"
        show-icon
        style="margin-bottom: 20px"
      />
      
      <div class="options">
        <el-card class="option-card" shadow="hover" @click="selectOption('reset')">
          <div class="option-content">
            <el-icon size="32" color="#f56c6c">
              <Delete />
            </el-icon>
            <h3>清除所有数据重设密码</h3>
            <p>将清除所有卡包数据、WebDAV配置和本地备份，然后设置新密码</p>
          </div>
        </el-card>
        
        <el-card class="option-card" shadow="hover" @click="selectOption('recover')">
          <div class="option-content">
            <el-icon size="32" color="#409eff">
              <Key />
            </el-icon>
            <h3>通过验证问题找回密码</h3>
            <p>回答3个基于您数据的验证问题来找回密码</p>
          </div>
        </el-card>
      </div>
      
      <div class="buttons">
        <el-button @click="visible = false">取消</el-button>
      </div>
    </div>
  </el-dialog>
</template>

<script setup>
import { computed, inject, watch } from 'vue'
import { Delete, Key } from '@element-plus/icons-vue'
import { useAutoLock } from '@/composables/useAutoLock'

const props = defineProps({
  modelValue: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['update:modelValue', 'option-selected'])
const providedAutoLock = inject('autoLock', null)
const { isLocked } = providedAutoLock || useAutoLock()

const visible = computed({
  get: () => props.modelValue,
  set: (value) => emit('update:modelValue', value)
})

const selectOption = (option) => {
  emit('option-selected', option)
  visible.value = false
}

watch(isLocked, (locked) => {
  if (locked && visible.value) {
    visible.value = false
  }
})
</script>

<style scoped>
.forgot-password {
  padding: 10px 0;
}

.options {
  display: flex;
  flex-direction: column;
  gap: 15px;
  margin: 20px 0;
}

.option-card {
  cursor: pointer;
  transition: all 0.3s;
}

.option-card:hover {
  transform: translateY(-2px);
}

.option-content {
  text-align: center;
  padding: 20px;
}

.option-content h3 {
  margin: 15px 0 10px 0;
  color: #303133;
}

.option-content p {
  color: #909399;
  font-size: 14px;
  margin: 0;
}

.buttons {
  text-align: center;
  margin-top: 20px;
}
</style>
