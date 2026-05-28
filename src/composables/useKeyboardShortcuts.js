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

    // 输入过程中不触发全局快捷键，避免 Ctrl+S/Ctrl+H 等组合键打断表单录入。
    if (isInputActive && event.key.toLowerCase() !== 'escape') {
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
  'ctrl+s': '统计分析',
  'ctrl+e': '导出数据',
  'ctrl+i': '导入数据',
  'ctrl+h': '使用帮助',
  'ctrl+t': '自定义列',
  'ctrl+b': '云端备份',
  'ctrl+shift+b': '本机备份',
  'ctrl+shift+w': '云同步设置',
  'ctrl+shift+c': '清除所有数据',
  'f1': '使用帮助',
  'escape': '关闭当前弹窗'
}
