<template>
  <div class="search-form">
    <el-form :inline="true" :model="formData" :label-width="labelWidth">
      <el-row :gutter="10" class="search-row">
        <el-form-item label="国家">
          <el-select v-model="formData.country" placeholder="请选择国家" filterable allow-create clearable>
            <el-option 
              v-for="(item, index) in options.countryData" 
              :key="index"
              :label="`${item.chineseName}(${item.name})`" 
              :value="item.chineseName" 
            />
          </el-select>
        </el-form-item>
        <el-form-item label="银行">
          <el-select v-model="formData.bank" placeholder="请选择银行" filterable allow-create clearable>
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
          <el-select v-model="formData.level" placeholder="请选择等级" filterable clearable>
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
          <el-select v-model="formData.type" placeholder="请选择币种" filterable clearable>
            <el-option 
              v-for="item in options.currencyList" 
              :key="item.name" 
              :label="item.name"
              :value="item.chineseName" 
            />
          </el-select>
        </el-form-item>
        <el-form-item label="年费达标">
          <el-select v-model="formData.isQualified" placeholder="请选择" filterable clearable>
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
      </el-row>
    </el-form>
  </div>
</template>

<script>
export default {
  name: 'SearchForm',
  props: {
    // 搜索表单数据
    modelValue: {
      type: Object,
      required: true
    },
    // 标签宽度
    labelWidth: {
      type: String,
      default: '80px'
    },
    // 选项数据
    options: {
      type: Object,
      required: true
    }
  },
  emits: ['update:modelValue'],
  computed: {
    formData: {
      get() {
        return this.modelValue
      },
      set(value) {
        this.$emit('update:modelValue', value)
      }
    }
  }
}
</script>

<style scoped>
.search-form {
  background-color: #fff;
  padding: 20px;
  border-radius: 4px;
  box-shadow: 0 2px 12px 0 rgba(0,0,0,0.1);
  margin-bottom: 20px;
}

.search-row {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin: 0 !important;
}

:deep(.el-form-item) {
  margin-bottom: 10px;
  margin-right: 0;
  flex: 1 1 300px;
}

:deep(.el-select) {
  width: 100%;
}
</style>
