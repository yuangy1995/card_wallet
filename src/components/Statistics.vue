<template>
  <div class="statistics-container" v-loading="loading" element-loading-text="正在分析数据...">
    <!-- 概览卡片 -->
    <div class="overview-cards">
      <el-row :gutter="20">
        <el-col :xs="24" :sm="12" :md="6">
          <el-card class="stat-card">
            <div class="stat-icon">🎫</div>
            <div class="stat-content">
              <div class="stat-title">信用卡总数</div>
              <div class="stat-value">{{ totalCards }}</div>
            </div>
          </el-card>
        </el-col>
        <el-col :xs="24" :sm="12" :md="6">
          <el-card class="stat-card">
            <div class="stat-icon">🏦</div>
            <div class="stat-content">
              <div class="stat-title">银行数量</div>
              <div class="stat-value">{{ totalBanks }}</div>
            </div>
          </el-card>
        </el-col>
        <el-col :xs="24" :sm="12" :md="6">
          <el-card class="stat-card">
            <div class="stat-icon">🌍</div>
            <div class="stat-content">
              <div class="stat-title">国家数量</div>
              <div class="stat-value">{{ totalCountries }}</div>
            </div>
          </el-card>
        </el-col>
        <el-col :xs="24" :sm="12" :md="6">
          <el-card class="stat-card">
            <div class="stat-icon">💰</div>
            <div class="stat-content">
              <div class="stat-title">币种数量</div>
              <div class="stat-value">{{ totalCurrencies }}</div>
            </div>
          </el-card>
        </el-col>
      </el-row>
    </div>

    <!-- 总额度汇总 -->
    <el-card class="total-limits-card">
          <template #header>
            <div class="card-header">
              <span>🎯 总额度汇总</span>
            </div>
          </template>
          <el-row :gutter="20">
            <el-col v-for="(amount, currency) in currencyTotals" :key="currency" :xs="12" :sm="8" :md="6">
              <div class="currency-total">
                <div class="currency-name">{{ currency }}</div>
                <div class="currency-amount">{{ formatCurrency(amount, currency) }}</div>
              </div>
            </el-col>
          </el-row>
        </el-card>

    <!-- 额度统计 -->
    <el-card class="limit-stats-card">
      <template #header>
        <div class="card-header">
          <span>💳 额度统计分析</span>
          <el-tooltip content="根据是否共享额度进行智能统计">
            <el-icon><QuestionFilled /></el-icon>
          </el-tooltip>
        </div>
      </template>
      <div class="limit-stats">
        <el-row :gutter="20">
          <el-col :xs="24" :lg="12">
            <div class="limit-section">
              <h4>💼 共享额度银行</h4>
              <div v-if="sharedLimitStats.length === 0" class="empty-state">
                暂无共享额度的银行
              </div>
              <div v-else class="limit-list">
                <div v-for="item in sharedLimitStats" :key="item.key" class="limit-item shared">
                  <div class="bank-info">
                    <div class="bank-name">{{ item.country }} - {{ item.bank }}</div>
                    <div class="card-count">{{ item.cardCount }} 张卡片共享</div>
                  </div>
                  <div class="limit-amount">
                    {{ formatCurrency(item.totalLimit, item.currency) }}
                  </div>
                </div>
              </div>
            </div>
          </el-col>
          <el-col :xs="24" :lg="12">
            <div class="limit-section">
              <h4>📋 独立额度卡片</h4>
              <div v-if="independentLimitStats.length === 0" class="empty-state">
                暂无独立额度的卡片
              </div>
              <div v-else class="limit-list">
                <div v-for="item in independentLimitStats" :key="item.key" class="limit-item independent">
                  <div class="bank-info">
                    <div class="bank-name">{{ item.country }} - {{ item.bank }}</div>
                    <div class="card-alias">{{ item.alias }}</div>
                  </div>
                  <div class="limit-amount">
                    {{ formatCurrency(item.limit, item.currency) }}
                  </div>
                </div>
              </div>
            </div>
          </el-col>
        </el-row>
        
        

        <!-- 新增分析模块 -->
        <el-row :gutter="20">
          <el-col :xs="24" :lg="12">
            <el-card class="analysis-card">
              <template #header>
                <div class="card-header">
                  <span>⭐ 卡片等级分布</span>
                </div>
              </template>
              <div class="level-stats">
                <div v-for="item in levelStats" :key="item.level" class="level-item">
                  <div class="level-info">
                    <span class="level-name">{{ item.level }}</span>
                    <span class="level-count">{{ item.count }} 张</span>
                  </div>
                  <div class="level-bar">
                    <div class="level-progress" :style="{ width: item.percentage + '%' }"></div>
                  </div>
                </div>
              </div>
            </el-card>
          </el-col>
          <el-col :xs="24" :lg="12">
            <el-card class="analysis-card">
              <template #header>
                <div class="card-header">
                  <span>💰 年费分析</span>
                </div>
              </template>
              <el-row :gutter="16">
                <el-col :xs="24" :sm="8">
                  <div class="annual-summary-item">
                    <div class="summary-label">总年费</div>
                    <div class="summary-value">¥{{ totalAnnualFee.toLocaleString() }}</div>
                  </div>
                </el-col>
                <el-col :xs="24" :sm="8">
                  <div class="annual-summary-item">
                    <div class="summary-label">平均年费</div>
                    <div class="summary-value">¥{{ avgAnnualFee.toLocaleString() }}</div>
                  </div>
                </el-col>
                <el-col :xs="24" :sm="8">
                  <div class="annual-summary-item">
                    <div class="summary-label">免年费卡</div>
                    <div class="summary-value">{{ freeAnnualFeeCards }} 张</div>
                  </div>
                </el-col>
              </el-row>
            </el-card>
          </el-col>
        </el-row>

        <el-row :gutter="20">
          <el-col :xs="24" :lg="12">
            <el-card class="analysis-card">
              <template #header>
                <div class="card-header">
                  <span>📅 卡片有效期分析</span>
                </div>
              </template>
              <div class="expiry-stats">
                <div class="expiry-item warning" v-if="expiryStats.expiredCards > 0">
                  <el-icon><WarningFilled /></el-icon>
                  <span>已过期: {{ expiryStats.expiredCards }} 张</span>
                </div>
                <div class="expiry-item danger" v-if="expiryStats.soonExpiring > 0">
                  <el-icon><Clock /></el-icon>
                  <span>6个月内到期: {{ expiryStats.soonExpiring }} 张</span>
                </div>
                <div class="expiry-item success">
                  <el-icon><Check /></el-icon>
                  <span>有效期正常: {{ expiryStats.normalCards }} 张</span>
                </div>
              </div>
            </el-card>
          </el-col>
          <el-col :xs="24" :lg="12">
            <el-card class="analysis-card">
              <template #header>
                <div class="card-header">
                  <span>📈 提额分析</span>
                </div>
              </template>
              <div class="raise-limit-stats">
                <div class="raise-stat-item">
                  <div class="stat-label">近6个月提额</div>
                  <div class="stat-value">{{ raiseLimitStats.recent6Months }} 张</div>
                </div>
                <div class="raise-stat-item">
                  <div class="stat-label">近1年提额</div>
                  <div class="stat-value">{{ raiseLimitStats.recent1Year }} 张</div>
                </div>
                <div class="raise-stat-item">
                  <div class="stat-label">从未提额</div>
                  <div class="stat-value">{{ raiseLimitStats.never }} 张</div>
                </div>
              </div>
            </el-card>
          </el-col>
        </el-row>
      </div>
    </el-card>

    <!-- 年费状态分析 -->
    <el-card class="annual-fee-card">
      <template #header>
        <div class="card-header">
          <span>⏰ 年费状态分析</span>
        </div>
      </template>
      <el-row :gutter="20">
        <el-col :xs="24" :sm="6">
          <div class="annual-stat-item normal">
            <div class="annual-title">已达标</div>
            <div class="annual-value">{{ annualFeeStats.qualified }}</div>
          </div>
        </el-col>
        <el-col :xs="24" :sm="6">
          <div class="annual-stat-item warning">
            <div class="annual-title">未达标</div>
            <div class="annual-value">{{ annualFeeStats.unqualified }}</div>
          </div>
        </el-col>
        <el-col :xs="24" :sm="6">
          <div class="annual-stat-item danger">
            <div class="annual-title">即将到期</div>
            <div class="annual-value">{{ annualFeeStats.warning }}</div>
          </div>
        </el-col>
        <el-col :xs="24" :sm="6">
          <div class="annual-stat-item success">
            <div class="annual-title">终身免费</div>
            <div class="annual-value">{{ annualFeeStats.lifetime }}</div>
          </div>
        </el-col>
      </el-row>
    </el-card>

    <!-- 分布图表 -->
    <el-row :gutter="20">
      <el-col :xs="24" :lg="12">
        <el-card class="chart-card">
          <template #header>
            <div class="card-header">
              <span>🏦 银行分布</span>
            </div>
          </template>
          <div ref="bankChart" class="chart"></div>
        </el-card>
      </el-col>
      <el-col :xs="24" :lg="12">
        <el-card class="chart-card">
          <template #header>
            <div class="card-header">
              <span>🌍 国家分布</span>
            </div>
          </template>
          <div ref="countryChart" class="chart"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 详细数据表格 -->
    <el-card class="table-card">
      <template #header>
        <div class="card-header">
          <span>📊 详细数据分析</span>
          <el-button type="primary" size="small" @click="exportData">
            <el-icon><Download /></el-icon>
            导出数据
          </el-button>
        </div>
      </template>
      <el-table :data="detailedStats" stripe>
        <el-table-column prop="country" label="国家" width="100" />
        <el-table-column prop="bank" label="银行" width="150" />
        <el-table-column prop="currency" label="币种" width="80" />
        <el-table-column prop="cardCount" label="卡片数" width="80" align="right" />
        <el-table-column prop="sharedType" label="额度类型" width="100">
          <template #default="{ row }">
            <el-tag v-if="row.isShared" type="success" size="small">共享</el-tag>
            <el-tag v-else type="info" size="small">独立</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="totalLimit" label="总额度" align="right">
          <template #default="{ row }">
            {{ formatCurrency(row.totalLimit, row.currency) }}
          </template>
        </el-table-column>
        <el-table-column prop="avgLimit" label="平均额度" align="right">
          <template #default="{ row }">
            {{ formatCurrency(row.avgLimit, row.currency) }}
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { QuestionFilled, Download, WarningFilled, Clock, Check } from '@element-plus/icons-vue'
import * as echarts from 'echarts'
import { BACKUP_CONSTANTS } from '@/config/constants'

// Props
const props = defineProps({
  cardData: {
    type: Array,
    required: true,
    default: () => []
  }
})

// 响应式数据
const loading = ref(false)
const bankChart = ref(null)
const countryChart = ref(null)

// 货币格式化
const formatCurrency = (amount, currency) => {
  const symbols = {
    'CNY': '¥',
    'USD': '$',
    'EUR': '€', 
    'GBP': '£',
    'JPY': '¥',
    'HKD': 'HK$',
    'TWD': 'NT$',
    'SGD': 'S$',
    '人民币': '¥',
    '美元': '$',
    '欧元': '€',
    '英镑': '£',
    '日元': '¥',
    '港币': 'HK$',
    '新台币': 'NT$',
    '新币': 'S$'
  }
  const symbol = symbols[currency] || currency
  return `${symbol}${amount.toLocaleString()}`
}

// 基础统计
const totalCards = computed(() => props.cardData.length)

const totalBanks = computed(() => {
  const banks = new Set(props.cardData.map(card => 
    (card.bank || '').replace(/\(.*?\)/g, "").trim()
  ))
  return banks.size
})

const totalCountries = computed(() => {
  const countries = new Set(props.cardData.map(card => card.country))
  return countries.size
})

const totalCurrencies = computed(() => {
  const currencies = new Set(props.cardData.map(card => card.type))
  return currencies.size
})

// 额度统计分析（考虑共享额度）
const sharedLimitStats = computed(() => {
  const sharedGroups = new Map()
  
  props.cardData.forEach(card => {
    if (card.isSharedLimit) {
      const key = `${card.country}-${card.bank.replace(/\(.*?\)/g, "").trim()}-${card.type}`
      if (!sharedGroups.has(key)) {
        sharedGroups.set(key, {
          key,
          country: card.country,
          bank: card.bank.replace(/\(.*?\)/g, "").trim(),
          currency: card.type,
          totalLimit: parseFloat(card.limit) || 0,
          cardCount: 0
        })
      }
      sharedGroups.get(key).cardCount++
    }
  })
  
  return Array.from(sharedGroups.values()).sort((a, b) => b.totalLimit - a.totalLimit)
})

const independentLimitStats = computed(() => {
  return props.cardData
    .filter(card => !card.isSharedLimit)
    .map(card => ({
      key: card.id,
      country: card.country,
      bank: card.bank.replace(/\(.*?\)/g, "").trim(),
      alias: card.alias,
      currency: card.type,
      limit: parseFloat(card.limit) || 0
    }))
    .sort((a, b) => b.limit - a.limit)
})

// 按币种汇总总额度
const currencyTotals = computed(() => {
  const totals = {}
  
  // 共享额度统计
  sharedLimitStats.value.forEach(item => {
    totals[item.currency] = (totals[item.currency] || 0) + item.totalLimit
  })
  
  // 独立额度统计
  independentLimitStats.value.forEach(item => {
    totals[item.currency] = (totals[item.currency] || 0) + item.limit
  })
  
  return totals
})

// 年费状态统计
const annualFeeStats = computed(() => {
  const now = new Date()
  let qualified = 0, unqualified = 0, warning = 0, lifetime = 0
  
  props.cardData.forEach(card => {
    if (card.isQualified === '1') qualified++
    else if (card.isQualified === '2') unqualified++
    else if (card.isQualified === '3') lifetime++
    
    // 检查即将到期的年费
    if (card.nextAnnualFeeCollectionTime && card.isQualified !== '3') {
      const dueDate = new Date(card.nextAnnualFeeCollectionTime)
      const diffDays = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24))
      if (diffDays <= 60 && diffDays > 0) warning++
    }
  })
  
  return { qualified, unqualified, warning, lifetime }
})

// 卡片等级分布统计
const levelStats = computed(() => {
  const levelMap = new Map()
  
  props.cardData.forEach(card => {
    const level = card.level || '未知'
    levelMap.set(level, (levelMap.get(level) || 0) + 1)
  })
  
  const total = props.cardData.length
  const stats = Array.from(levelMap.entries())
    .map(([level, count]) => ({
      level,
      count,
      percentage: total > 0 ? Math.round((count / total) * 100) : 0
    }))
    .sort((a, b) => b.count - a.count)
  
  return stats
})

// 年费分析统计
const totalAnnualFee = computed(() => {
  return props.cardData.reduce((total, card) => {
    return total + (parseFloat(card.annualFee) || 0)
  }, 0)
})

const avgAnnualFee = computed(() => {
  return props.cardData.length > 0 ? Math.round(totalAnnualFee.value / props.cardData.length) : 0
})

const freeAnnualFeeCards = computed(() => {
  return props.cardData.filter(card => 
    parseFloat(card.annualFee) === 0 || card.isQualified === '3'
  ).length
})

// 卡片有效期分析
const expiryStats = computed(() => {
  const now = new Date()
  const sixMonthsLater = new Date()
  sixMonthsLater.setMonth(now.getMonth() + 6)
  
  let expiredCards = 0, soonExpiring = 0, normalCards = 0
  
  props.cardData.forEach(card => {
    if (card.valid) {
      const [month, year] = card.valid.split('/')
      const expiryDate = new Date(2000 + parseInt(year), parseInt(month) - 1)
      
      if (expiryDate < now) {
        expiredCards++
      } else if (expiryDate < sixMonthsLater) {
        soonExpiring++
      } else {
        normalCards++
      }
    }
  })
  
  return { expiredCards, soonExpiring, normalCards }
})

// 提额分析统计
const raiseLimitStats = computed(() => {
  const now = new Date()
  const sixMonthsAgo = new Date()
  sixMonthsAgo.setMonth(now.getMonth() - 6)
  const oneYearAgo = new Date()
  oneYearAgo.setFullYear(now.getFullYear() - 1)
  
  let recent6Months = 0, recent1Year = 0, never = 0
  
  props.cardData.forEach(card => {
    if (card.lastTime) {
      const lastRaiseDate = new Date(card.lastTime)
      if (lastRaiseDate >= sixMonthsAgo) {
        recent6Months++
      } else if (lastRaiseDate >= oneYearAgo) {
        recent1Year++
      }
    } else {
      never++
    }
  })
  
  return { recent6Months, recent1Year, never }
})

// 详细数据表格
const detailedStats = computed(() => {
  const stats = []
  
  // 共享额度数据
  sharedLimitStats.value.forEach(item => {
    stats.push({
      country: item.country,
      bank: item.bank,
      currency: item.currency,
      cardCount: item.cardCount,
      isShared: true,
      totalLimit: item.totalLimit,
      avgLimit: item.totalLimit // 共享额度平均额度就是总额度
    })
  })
  
  // 独立额度数据按银行分组
  const independentGroups = new Map()
  independentLimitStats.value.forEach(item => {
    const key = `${item.country}-${item.bank}-${item.currency}`
    if (!independentGroups.has(key)) {
      independentGroups.set(key, {
        country: item.country,
        bank: item.bank,
        currency: item.currency,
        cardCount: 0,
        totalLimit: 0,
        isShared: false
      })
    }
    const group = independentGroups.get(key)
    group.cardCount++
    group.totalLimit += item.limit
  })
  
  independentGroups.forEach(group => {
    group.avgLimit = group.totalLimit / group.cardCount
    stats.push(group)
  })
  
  return stats.sort((a, b) => {
    if (a.country !== b.country) return a.country.localeCompare(b.country)
    if (a.bank !== b.bank) return a.bank.localeCompare(b.bank)
    return b.totalLimit - a.totalLimit
  })
})

// 初始化图表
const initCharts = async () => {
  loading.value = true
  
  try {
    // 模拟分析时间
    await new Promise(resolve => setTimeout(resolve, 1000))
    
    await nextTick()
    
    // 银行分布图表
    if (bankChart.value) {
      const bankInstance = echarts.init(bankChart.value)
      const bankData = {}
      props.cardData.forEach(card => {
        const bank = card.bank.replace(/\(.*?\)/g, "").trim()
        bankData[bank] = (bankData[bank] || 0) + 1
      })
      
      const bankChartData = Object.entries(bankData)
        .sort((a, b) => b[1] - a[1])
        .map(([name, value]) => ({ name, value }))
      
      bankInstance.setOption({
        tooltip: {
          trigger: 'item',
          formatter: '{b}: {c} 张 ({d}%)'
        },
        series: [{
          type: 'pie',
          radius: ['40%', '70%'],
          data: bankChartData,
          emphasis: {
            itemStyle: {
              shadowBlur: 10,
              shadowOffsetX: 0,
              shadowColor: 'rgba(0, 0, 0, 0.5)'
            }
          }
        }]
      })
    }
    
    // 国家分布图表
    if (countryChart.value) {
      const countryInstance = echarts.init(countryChart.value)
      const countryData = {}
      props.cardData.forEach(card => {
        countryData[card.country] = (countryData[card.country] || 0) + 1
      })
      
      const countryChartData = Object.entries(countryData)
        .sort((a, b) => b[1] - a[1])
        .map(([name, value]) => ({ name, value }))
      
      countryInstance.setOption({
        tooltip: {
          trigger: 'item',
          formatter: '{b}: {c} 张 ({d}%)'
        },
        series: [{
          type: 'pie',
          radius: ['40%', '70%'],
          data: countryChartData,
          emphasis: {
            itemStyle: {
              shadowBlur: 10,
              shadowOffsetX: 0,
              shadowColor: 'rgba(0, 0, 0, 0.5)'
            }
          }
        }]
      })
    }
  } finally {
    loading.value = false
  }
}

// 导出数据
const exportData = () => {
  const data = detailedStats.value.map(item => ({
    国家: item.country,
    银行: item.bank,
    币种: item.currency,
    卡片数: item.cardCount,
    额度类型: item.isShared ? '共享' : '独立',
    总额度: item.totalLimit,
    平均额度: item.avgLimit
  }))
  
  const csv = [
    Object.keys(data[0]).join(','),
    ...data.map(row => Object.values(row).join(','))
  ].join('\n')
  
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const link = document.createElement('a')
  link.href = URL.createObjectURL(blob)
  link.download = `信用卡统计分析_${new Date().toISOString().split('T')[0]}.csv`
  link.click()
  
  ElMessage.success('数据导出成功')
}

onMounted(() => {
  initCharts()
})

watch(() => props.cardData, () => {
  initCharts()
}, { deep: true })
</script>

<style scoped>
.statistics-container {
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.overview-cards {
  margin-bottom: 20px;
}

.stat-card {
  display: flex;
  align-items: center;
  padding: 20px;
  border-radius: 12px;
  transition: transform 0.3s ease;
  cursor: pointer;
}

.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.stat-icon {
  font-size: 32px;
  margin-right: 16px;
}

.stat-content {
  flex: 1;
}

.stat-title {
  font-size: 14px;
  color: var(--el-text-color-secondary);
  margin-bottom: 4px;
}

.stat-value {
  font-size: 24px;
  font-weight: bold;
  color: var(--el-text-color-primary);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-weight: bold;
}

.limit-stats {
  .limit-section {
    margin-bottom: 20px;
    
    h4 {
      margin-bottom: 16px;
      color: var(--el-text-color-primary);
      font-size: 16px;
    }
  }
  
  .empty-state {
    text-align: center;
    color: var(--el-text-color-secondary);
    padding: 40px;
    background: var(--el-fill-color-light);
    border-radius: 8px;
  }
  
  .limit-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  
  .limit-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px;
    border-radius: 8px;
    transition: background-color 0.3s ease;
    
    &.shared {
      background: linear-gradient(135deg, #e8f5e8 0%, #f0f9ff 100%);
      border-left: 4px solid #67c23a;
    }
    
    &.independent {
      background: linear-gradient(135deg, #fff7ed 0%, #fef3c7 100%);
      border-left: 4px solid #e6a23c;
    }
    
    .bank-info {
      flex: 1;
      
      .bank-name {
        font-weight: bold;
        margin-bottom: 4px;
        color: var(--el-text-color-primary);
      }
      
      .card-count, .card-alias {
        font-size: 12px;
        color: var(--el-text-color-secondary);
      }
    }
    
    .limit-amount {
      font-size: 18px;
      font-weight: bold;
      color: var(--el-color-primary);
    }
  }
  
}

.total-limits-card {
  margin-bottom: 20px;
  
  .currency-total {
    text-align: center;
    padding: 16px;
    background: var(--el-fill-color-light);
    border-radius: 8px;
    margin-bottom: 12px;
    
    .currency-name {
      font-size: 14px;
      color: var(--el-text-color-secondary);
      margin-bottom: 8px;
    }
    
    .currency-amount {
      font-size: 20px;
      font-weight: bold;
      color: var(--el-color-primary);
    }
  }
}

.analysis-card {
  margin-bottom: 20px;
}

.level-stats {
  .level-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
    
    .level-info {
      flex: 1;
      
      .level-name {
        font-weight: bold;
        margin-right: 16px;
        color: var(--el-text-color-primary);
      }
      
      .level-count {
        font-size: 12px;
        color: var(--el-text-color-secondary);
      }
    }
    
    .level-bar {
      width: 100px;
      height: 8px;
      background: var(--el-fill-color-light);
      border-radius: 4px;
      overflow: hidden;
      
      .level-progress {
        height: 100%;
        background: linear-gradient(90deg, var(--el-color-primary-light-3), var(--el-color-primary));
        border-radius: 4px;
        transition: width 0.3s ease;
      }
    }
  }
}

.annual-summary-item {
  text-align: center;
  padding: 16px;
  background: var(--el-fill-color-light);
  border-radius: 8px;
  margin-bottom: 12px;
  
  .summary-label {
    font-size: 12px;
    color: var(--el-text-color-secondary);
    margin-bottom: 8px;
  }
  
  .summary-value {
    font-size: 18px;
    font-weight: bold;
    color: var(--el-color-primary);
  }
}

.expiry-stats {
  .expiry-item {
    display: flex;
    align-items: center;
    padding: 12px;
    border-radius: 8px;
    margin-bottom: 12px;
    
    .el-icon {
      margin-right: 8px;
      font-size: 16px;
    }
    
    &.warning {
      background: #fefce8;
      color: #a16207;
    }
    
    &.danger {
      background: #fef2f2;
      color: #dc2626;
    }
    
    &.success {
      background: #f0fdf4;
      color: #16a34a;
    }
  }
}

.raise-limit-stats {
  .raise-stat-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px;
    background: var(--el-fill-color-light);
    border-radius: 8px;
    margin-bottom: 12px;
    
    .stat-label {
      font-size: 14px;
      color: var(--el-text-color-regular);
    }
    
    .stat-value {
      font-size: 16px;
      font-weight: bold;
      color: var(--el-color-primary);
    }
  }
}

.annual-stat-item {
  text-align: center;
  padding: 20px;
  border-radius: 8px;
  margin-bottom: 12px;
  
  .annual-title {
    font-size: 14px;
    margin-bottom: 8px;
  }
  
  .annual-value {
    font-size: 24px;
    font-weight: bold;
  }
  
  &.normal {
    background: #f0f9ff;
    color: #1e40af;
  }
  
  &.warning {
    background: #fefce8;
    color: #a16207;
  }
  
  &.danger {
    background: #fef2f2;
    color: #dc2626;
  }
  
  &.success {
    background: #f0fdf4;
    color: #16a34a;
  }
}

.chart {
  height: 300px;
}

.chart-card, .table-card {
  margin-bottom: 20px;
}

@media (max-width: 768px) {
  .statistics-container {
    padding: 12px;
  }
  
  .stat-card {
    flex-direction: column;
    text-align: center;
    
    .stat-icon {
      margin-right: 0;
      margin-bottom: 8px;
    }
  }
  
  .chart {
    height: 250px;
  }
}
</style>
