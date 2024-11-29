<template>
  <el-dialog
    v-model="dialogVisible"
    title="选择表格显示内容"
    width="30%"
    draggable
  >
    <el-checkbox-group v-model="selectedColumns">
      <el-checkbox
        v-for="item in columns"
        :key="item.prop"
        :label="item.prop"
        size="large"
      >
        {{ item.label }}
      </el-checkbox>
    </el-checkbox-group>

    <template #footer>
      <span class="dialog-footer">
        <el-button @click="handleCancel">取消</el-button>
        <el-button type="primary" @click="handleConfirm">确定</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script>
export default {
  name: 'TableCustomDialog',

  props: {
    visible: {
      type: Boolean,
      default: false
    },
    columns: {
      type: Array,
      required: true,
      default: () => []
    },
    initialSelection: {
      type: Array,
      default: () => []
    }
  },

  emits: ['update:visible', 'confirm'],

  data() {
    return {
      selectedColumns: []
    }
  },

  computed: {
    dialogVisible: {
      get() {
        return this.visible
      },
      set(value) {
        this.$emit('update:visible', value)
      }
    }
  },

  watch: {
    visible(newVal) {
      if (newVal) {
        // 当对话框打开时，初始化选中的列
        this.selectedColumns = [...this.initialSelection]
      }
    }
  },

  methods: {
    handleCancel() {
      this.dialogVisible = false
    },

    handleConfirm() {
      this.$emit('confirm', this.selectedColumns)
      this.dialogVisible = false
    }
  }
}
</script>

<style lang="scss" scoped>
.dialog-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 20px;
}

:deep(.el-checkbox-group) {
  display: flex;
  flex-direction: column;
  gap: 12px;

  .el-checkbox {
    margin-right: 0;
  }
}
</style>
