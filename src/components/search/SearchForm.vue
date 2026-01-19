<template>
  <el-card class="search-form" shadow="never">
    <template #header>
      <div class="search-header">
        <span>查询条件</span>
        <div class="search-actions">
          <el-button link type="primary" @click="toggleCollapse" size="small">
            {{ isCollapse ? '展开' : '收起' }}
            <el-icon><ArrowDown :class="{ 'is-reverse': !isCollapse }" /></el-icon>
          </el-button>
          <el-button link type="danger" @click="resetForm" size="small">重置</el-button>
        </div>
      </div>
    </template>

    <el-form :inline="true" :model="formData" :label-width="labelWidth" size="small">
      <div class="form-content">
        <div class="first-row">
          <el-form-item label="别名">
            <el-input v-model="formData.alias" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="国家">
            <el-select v-model="formData.country" placeholder="请选择国家" filterable allow-create clearable multiple collapse-tags>
              <el-option 
                v-for="(item, index) in options.countryData" 
                :key="index"
                :label="`${item.chineseName}(${item.name})`" 
                :value="item.chineseName" 
              />
            </el-select>
          </el-form-item>
          <el-form-item label="银行">
            <el-select v-model="formData.bank" placeholder="请选择银行" filterable allow-create clearable multiple collapse-tags>
              <el-option 
                v-for="item in options.bankList" 
                :key="item.name" 
                :label="item.name"
                :value="item.chineseName" 
              />
            </el-select>
          </el-form-item>
          <el-form-item label="卡号">
            <el-input v-model="formData.cardNumber" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="等级">
            <el-select v-model="formData.level" placeholder="请选择等级" filterable clearable multiple collapse-tags>
              <el-option 
                v-for="item in options.cardLevel" 
                :key="item.name" 
                :label="item.name"
                :value="item.chineseName" 
              />
            </el-select>
          </el-form-item>
          <el-form-item label="额度">
            <el-input v-model="formData.limit" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="币种">
            <el-select v-model="formData.type" placeholder="请选择币种" filterable clearable multiple collapse-tags>
              <el-option 
                v-for="item in options.currencyList" 
                :key="item.name" 
                :label="item.name"
                :value="item.chineseName" 
              />
            </el-select>
          </el-form-item>
        </div>
        <div v-show="!isCollapse" class="extra-rows">
          <el-form-item label="年费达标">
            <el-select v-model="formData.isQualified" placeholder="请选择" filterable clearable multiple collapse-tags>
              <el-option 
                v-for="item in options.isQualified" 
                :key="item.name" 
                :label="item.name"
                :value="item.value" 
              />
            </el-select>
          </el-form-item>
          <el-form-item label="权益">
            <el-input v-model="formData.equity" autocomplete="off" clearable />
          </el-form-item>
          <el-form-item label="备注">
            <el-input v-model="formData.remark" autocomplete="off" clearable />
          </el-form-item>
        </div>
      </div>
    </el-form>
  </el-card>
</template>

<script>
import { ref, computed, onMounted } from 'vue'
import { useDebouncedRef } from '@/composables/useDebounce'
import { ArrowDown } from '@element-plus/icons-vue'

export default {
  name: 'SearchForm',
  components: {
    ArrowDown
  },
  props: {
    modelValue: {
      type: Object,
      required: true
    },
    labelWidth: {
      type: String,
      default: '70px'
    },
    options: {
      type: Object,
      required: true
    }
  },
  emits: ['update:modelValue'],
  setup(props, { emit }) {
    const isCollapse = ref(true)

    const formData = computed({
      get: () => props.modelValue,
      set: (value) => emit('update:modelValue', value)
    })

    const toggleCollapse = () => {
      isCollapse.value = !isCollapse.value
    }

    const resetForm = () => {
      emit('update:modelValue', {
        alias: '',
        country: '',
        bank: '',
        cardNumber: '',
        level: '',
        limit: '',
        type: '',
        isQualified: '',
        equity: '',
        remark: ''
      })
    }

    return {
      formData,
      isCollapse,
      toggleCollapse,
      resetForm
    }
  }
}
</script>

<style lang="scss" scoped>
.search-form {
  margin-bottom: 12px;
  background-color: var(--el-bg-color);
  
  :deep(.el-card__header) {
    padding: 8px 12px;
    border-bottom: 1px solid var(--el-border-color-lighter);
    background-color: var(--el-fill-color-blank);
  }
  
  :deep(.el-card__body) {
    padding: 12px 16px;
    background-color: var(--el-fill-color-blank);
  }
  
  .search-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 14px;
    font-weight: 500;
    color: var(--el-text-color-primary);

    .search-actions {
      display: flex;
      gap: 8px;

      :deep(.el-button) {
        padding: 4px 8px;
        height: 24px;
        font-size: 12px;
      }
    }
  }

  .form-content {
    .first-row,
    .extra-rows {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      width: 100%;
    }

    .extra-rows {
      margin-top: 8px;
    }
    
    :deep(.el-form-item) {
      margin: 0;
      flex: 0 0 auto;
      min-width: 200px;
      
      .el-form-item__content {
        margin-left: 8px !important;
        flex: 1;
        min-width: 0;
        
        .el-select,
        .el-input {
          width: 100%;
        }
      }
    }
  }

  .is-reverse {
    transform: rotate(180deg);
    transition: transform 0.3s ease;
  }
}
</style>
