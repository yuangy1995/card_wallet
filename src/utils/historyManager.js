// 历史记录管理
const HISTORY_KEY = 'credit_card_history'
const MAX_HISTORY = 15

export class HistoryRecord {
  constructor(type, count, data, previousData) {
    this.timestamp = new Date().toISOString()
    this.type = type // 'add', 'delete', 'import', 'webdav_restore', 'rollback'
    this.count = count
    this.data = data // 当前数据
    this.previousData = previousData // 操作前的数据
  }
}

export const HistoryManager = {
  // 获取所有历史记录
  getHistory() {
    const history = localStorage.getItem(HISTORY_KEY)
    return history ? JSON.parse(history) : []
  },

  // 添加新的历史记录
  addHistory(record) {
    let history = this.getHistory()
    history.unshift(record)
    
    // 保持最多15条记录
    if (history.length > MAX_HISTORY) {
      history = history.slice(0, MAX_HISTORY)
    }
    
    localStorage.setItem(HISTORY_KEY, JSON.stringify(history))
  },

  // 删除指定索引的历史记录
  removeHistory(index) {
    const history = this.getHistory()
    history.splice(index, 1)
    localStorage.setItem(HISTORY_KEY, JSON.stringify(history))
  },

  // 清空历史记录
  clearHistory() {
    localStorage.removeItem(HISTORY_KEY)
  }
}
