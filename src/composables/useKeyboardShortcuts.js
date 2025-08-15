/**
 * 键盘快捷键 Composable
 */
import { onMounted, onUnmounted } from 'vue'

export function useKeyboardShortcuts(shortcuts = {}) {
  const handleKeydown = (event) => {
    // 检查是否在输入框中
    const activeElement = document.activeElement
    const isInputActive = activeElement && (
      activeElement.tagName === 'INPUT' || 
      activeElement.tagName === 'TEXTAREA' || 
      activeElement.contentEditable === 'true'
    )

    // 如果在输入框中，跳过大部分快捷键
    if (isInputActive && !event.ctrlKey && !event.metaKey) {
      return
    }

    const key = event.key.toLowerCase()
    const ctrl = event.ctrlKey || event.metaKey
    const shift = event.shiftKey
    const alt = event.altKey

    // 构建快捷键字符串
    let shortcutKey = ''
    if (ctrl) shortcutKey += 'ctrl+'
    if (shift) shortcutKey += 'shift+'
    if (alt) shortcutKey += 'alt+'
    shortcutKey += key

    // 查找匹配的快捷键
    const handler = shortcuts[shortcutKey]
    if (handler && typeof handler === 'function') {
      event.preventDefault()
      handler()
    }
  }

  onMounted(() => {
    document.addEventListener('keydown', handleKeydown)
  })

  onUnmounted(() => {
    document.removeEventListener('keydown', handleKeydown)
  })

  return {
    handleKeydown
  }
}

// 预定义的快捷键配置
export const DEFAULT_SHORTCUTS = {
  // 基本操作
  'ctrl+n': '新增信用卡',
  'ctrl+s': '保存',
  'ctrl+e': '导出数据',
  'ctrl+i': '导入数据',
  'ctrl+f': '搜索',
  'escape': '关闭弹窗',
  
  // 导航
  'ctrl+1': '切换到第一个标签',
  'ctrl+2': '切换到第二个标签',
  'ctrl+3': '切换到第三个标签',
  
  // 表格操作
  'ctrl+a': '全选',
  'delete': '删除选中项',
  'f2': '编辑选中项',
  
  // 视图操作
  'ctrl+shift+s': '统计分析',
  'ctrl+shift+h': '使用帮助',
  'ctrl+shift+c': '自定义列',
  
  // 数据操作
  'ctrl+shift+g': '生成随机数据',
  'ctrl+shift+x': '清除所有数据',
  'ctrl+b': '备份数据',
  'ctrl+r': '恢复数据'
}
