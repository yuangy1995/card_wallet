<template>
  <el-dialog
    v-model="visible"
    width="80%"
    class="help-dialog"
    :close-on-click-modal="false"
    :close-on-press-escape="true"
    draggable
    :modal-class="'help-dialog-modal'"
  >
    <el-scrollbar height="70vh" class="help-scrollbar">
      <div class="help-content">
        <h2>信用卡管理系统使用指南</h2>
        
        <el-divider content-position="left">快速开始</el-divider>
        <div class="section">
          <h3>🚀 基础操作</h3>
          <ol>
            <li>
              <strong>添加新卡：</strong>
              <p>点击顶部的"新增信用卡"按钮，填写信用卡信息，包括：</p>
              <ul>
                <li>卡片名称（如：xx银行信用卡）</li>
                <li>卡号（支持加密显示）</li>
                <li>CVV码（支持加密显示）</li>
                <li>有效期</li>
                <li>额度和其他信息</li>
              </ul>
            </li>
            <li>
              <strong>查看卡片：</strong>
              <p>所有信用卡信息将在主表格中显示，支持：</p>
              <ul>
                <li>点击表头排序</li>
                <li>使用搜索栏筛选</li>
                <li>自定义显示列</li>
              </ul>
            </li>
          </ol>
        </div>

        <el-divider content-position="left">核心功能</el-divider>
        <div class="section">
          <h3>🔍 搜索和筛选</h3>
          <ul>
            <li>支持多条件组合搜索</li>
            <li>可按卡片状态、银行、额度等进行筛选</li>
            <li>支持模糊搜索和精确匹配</li>
          </ul>

          <h3>🔒 数据安全</h3>
          <ul>
            <li>敏感信息（卡号、CVV）默认加密显示</li>
            <li>点击眼睛图标可临时查看完整信息</li>
            <li>所有数据使用AES加密存储</li>
          </ul>

          <h3>📊 数据管理</h3>
          <ul>
            <li><strong>导出数据：</strong>
              <p>点击"导出数据"按钮，系统会将所有信用卡信息导出为加密文件：</p>
              <ul>
                <li>可设置自定义密码保护</li>
                <li>导出为加密格式，方便安全的备份和迁移</li>
              </ul>
            </li>
            <li><strong>导入数据：</strong>
              <p>点击"导入数据"按钮，可导入之前导出的数据文件：</p>
              <ul>
                <li>需要输入导出时设置的密码</li>
              </ul>
            </li>
          </ul>
        </div>

        <el-divider content-position="left">高级功能</el-divider>
        <div class="section">
          <h3>⏰ 年费管理</h3>
          <ul>
            <li>系统自动检测年费到期情况</li>
            <li>可手动标记年费达标状态</li>
            <li>显示距离上次提额天数</li>
          </ul>

          <h3>📈 数据分析</h3>
          <ul>
            <li>查看信用卡使用统计</li>
            <li>额度分布分析</li>
            <li>银行占比统计</li>
          </ul>

          <h3>⚙️ 个性化设置</h3>
          <ul>
            <li><strong>表格定制：</strong>
              <p>点击"自定义列"按钮可以：</p>
              <ul>
                <li>选择要显示的列</li>
              </ul>
            </li>
          </ul>
        </div>

        <el-divider content-position="left">使用技巧</el-divider>
        <div class="section">
          <h3>💡 快捷操作</h3>
          <ul>
            <li><strong>表格右键菜单：</strong>
              <p>在表格行上右键点击可快速：</p>
              <ul>
                <li>编辑卡片信息</li>
                <li>删除卡片</li>
                <li>查看详情</li>
              </ul>
            </li>
            <li><strong>数据备份建议：</strong>
              <ul>
                <li>定期导出数据保存</li>
                <li>更新重要信息后及时备份</li>
                <li>妥善保管导出文件的密码</li>
              </ul>
            </li>
          </ul>
        </div>
      </div>
    </el-scrollbar>
    <template #footer>
      <span class="dialog-footer">
        <el-button @click="visible = false">关闭</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, watch } from 'vue'

const visible = ref(false)

// 监听对话框显示状态，当显示时禁用body滚动
watch(visible, (val) => {
  if (val) {
    document.body.style.overflow = 'hidden'
  } else {
    document.body.style.overflow = ''
  }
})

const showHelp = () => {
  visible.value = true
}

defineExpose({
  showHelp
})
</script>

<style lang="scss" scoped>
.help-dialog {
  :deep(.el-dialog) {
    margin: 0;
    position: relative;
    margin: 15vh auto 50px;
    display: flex;
    flex-direction: column;
    max-height: 85vh;
    
    .el-dialog__header {
      cursor: move;
      background: var(--el-color-primary-light-8);
      margin: 0;
      padding: 15px 20px;
      border-bottom: 1px solid var(--el-border-color-lighter);
      flex-shrink: 0;
    }

    .el-dialog__body {
      padding: 0;
      flex: 1;
      overflow: hidden;
    }

    .el-dialog__footer {
      border-top: 1px solid var(--el-border-color-lighter);
      padding: 15px 20px;
      flex-shrink: 0;
    }
  }
}

.help-scrollbar {
  overflow: hidden;
  
  :deep(.el-scrollbar__wrap) {
    overflow-x: hidden;
  }
}

.help-content {
  padding: 20px;
  
  h2 {
    text-align: center;
    color: var(--el-color-primary);
    margin-bottom: 20px;
  }

  .section {
    margin-bottom: 20px;

    h3 {
      color: var(--el-color-primary);
      margin: 15px 0;
    }

    ul, ol {
      padding-left: 20px;
      margin: 10px 0;

      li {
        margin: 8px 0;
        line-height: 1.5;

        strong {
          color: var(--el-color-primary);
        }

        p {
          margin: 5px 0;
        }

        ul {
          margin: 5px 0;
        }
      }
    }
  }

  .el-divider__text {
    font-size: 18px;
    font-weight: bold;
    color: var(--el-color-primary);
  }
}
</style>

<style>
.help-dialog-modal {
  overflow: hidden;
}
</style>
