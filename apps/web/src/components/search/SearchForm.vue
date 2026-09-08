<template>
  <div class="search-form-clean">
    <el-form :inline="true" :model="formData" :label-width="labelWidth" size="small">
      <div class="form-grid-layout">
        <el-form-item label="卡类别">
          <el-select v-model="formData.cardCategory" placeholder="请选择卡类别" filterable clearable multiple collapse-tags>
            <el-option
              v-for="item in options.cardCategory"
              :key="item.value"
              :label="item.label"
              :value="item.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="别名">
          <el-input v-model="formData.alias" autocomplete="off" clearable />
        </el-form-item>
        <el-form-item label="国家">
          <el-select v-model="formData.country" placeholder="请选择国家" filterable allow-create clearable multiple collapse-tags>
            <el-option 
              v-for="(item, index) in options.countryData" 
              :key="index"
              :label="item.chineseName" 
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
    </el-form>
  </div>
</template>

<script>
import { computed } from 'vue'

export default {
  name: 'SearchForm',
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
    },
    isCollapse: {
      type: Boolean,
      default: false
    }
  },
  emits: ['update:modelValue'],
  setup(props, { emit }) {
    const formData = computed({
      get: () => props.modelValue,
      set: (value) => emit('update:modelValue', value)
    })

    return {
      formData
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

    .search-title {
      display: flex;
      align-items: center;
      gap: 8px;
      flex: 0 0 auto;
    }

    .search-header-extra {
      flex: 1 1 auto;
      min-width: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 0 12px;
    }

    .search-actions {
      display: flex;
      flex: 0 0 auto;
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

  @media (max-width: 900px) {
    .search-header {
      flex-wrap: wrap;
      gap: 8px;
    }

    .search-header-extra {
      order: 3;
      flex-basis: 100%;
      justify-content: flex-start;
      padding: 0;
    }
  }
}
</style>
