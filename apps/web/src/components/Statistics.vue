<template>
  <div class="statistics-container" v-loading="loading" element-loading-text="正在分析数据...">
    <template v-if="isReady">
      <!-- 统计筛选器 -->
      <div class="statistics-filter-wrapper">
      <el-radio-group v-model="selectedCategory" size="default" class="tech-radio-group">
        <el-radio-button value="all">📊 全部卡片 ({{ props.cardData.length }})</el-radio-button>
        <el-radio-button value="credit">💳 仅信用卡 ({{ creditCountAll }})</el-radio-button>
        <el-radio-button value="debit">🏧 仅储蓄卡 ({{ debitCountAll }})</el-radio-button>
      </el-radio-group>
    </div>

    <!-- 概览卡片 -->
    <div class="overview-cards">
      <el-row :gutter="20">
        <el-col :xs="24" :sm="12" :md="6">
          <el-card class="stat-card">
            <div class="stat-icon">🎫</div>
            <div class="stat-content">
              <div class="stat-title">银行卡总数</div>
              <div class="stat-value">{{ totalCards }}</div>
            </div>
          </el-card>
        </el-col>
        <el-col :xs="24" :sm="12" :md="6">
          <el-card class="stat-card">
            <div class="stat-icon">🏦</div>
            <div class="stat-content">
              <div class="stat-title">信用卡</div>
              <div class="stat-value">{{ creditCardCount }}</div>
            </div>
          </el-card>
        </el-col>
        <el-col :xs="24" :sm="12" :md="6">
          <el-card class="stat-card">
            <div class="stat-icon">🌍</div>
            <div class="stat-content">
              <div class="stat-title">储蓄卡</div>
              <div class="stat-value">{{ debitCardCount }}</div>
            </div>
          </el-card>
        </el-col>
        <el-col :xs="24" :sm="12" :md="6">
          <el-card class="stat-card">
            <div class="stat-icon">💰</div>
            <div class="stat-content">
              <div class="stat-title">银行数量</div>
              <div class="stat-value">{{ totalBanks }}</div>
            </div>
          </el-card>
        </el-col>
      </el-row>
    </div>

    <el-card v-if="debitCardCount > 0" class="total-limits-card">
      <template #header>
        <div class="card-header collapse-header" @click="collapsedPanels.debitDistribution = !collapsedPanels.debitDistribution">
          <span>🏧 储蓄卡分布</span>
          <div class="header-actions">
            <span class="fold-text">{{ collapsedPanels.debitDistribution ? '展开' : '收起' }}</span>
            <el-icon :class="{ 'is-collapsed': collapsedPanels.debitDistribution }" class="fold-arrow">
              <ArrowDown />
            </el-icon>
          </div>
        </div>
      </template>
      <div v-show="!collapsedPanels.debitDistribution">
        <el-row :gutter="20">
          <el-col :xs="24" :sm="8">
            <div class="currency-total">
              <div class="currency-name">国家/地区</div>
              <div class="currency-amount">{{ debitCountryCount }}</div>
            </div>
          </el-col>
          <el-col :xs="24" :sm="8">
            <div class="currency-total">
              <div class="currency-name">银行</div>
              <div class="currency-amount">{{ debitBankCount }}</div>
            </div>
          </el-col>
          <el-col :xs="24" :sm="8">
            <div class="currency-total">
              <div class="currency-name">币种</div>
              <div class="currency-amount">{{ debitCurrencyCount }}</div>
            </div>
          </el-col>
        </el-row>
      </div>
    </el-card>

    <el-card v-if="hasExpiryStats" class="total-limits-card">
      <template #header>
        <div class="card-header collapse-header" @click="collapsedPanels.expiryStats = !collapsedPanels.expiryStats">
          <span>📅 卡片有效期分析</span>
          <div class="header-actions">
            <span class="fold-text">{{ collapsedPanels.expiryStats ? '展开' : '收起' }}</span>
            <el-icon :class="{ 'is-collapsed': collapsedPanels.expiryStats }" class="fold-arrow">
              <ArrowDown />
            </el-icon>
          </div>
        </div>
      </template>
      <div v-show="!collapsedPanels.expiryStats" class="expiry-stats">
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

    <!-- 总额度汇总 -->
    <el-card v-if="creditCardCount > 0" class="total-limits-card">
      <template #header>
        <div class="card-header collapse-header" @click="collapsedPanels.creditTotals = !collapsedPanels.creditTotals">
          <span>🎯 信用卡总额度汇总</span>
          <div class="header-actions">
            <span class="fold-text">{{ collapsedPanels.creditTotals ? '展开' : '收起' }}</span>
            <el-icon :class="{ 'is-collapsed': collapsedPanels.creditTotals }" class="fold-arrow">
              <ArrowDown />
            </el-icon>
          </div>
        </div>
      </template>
      <div v-show="!collapsedPanels.creditTotals">
        <el-row :gutter="20">
          <el-col v-for="(amount, currency) in currencyTotals" :key="currency" :xs="12" :sm="8" :md="6">
            <div class="currency-total">
              <div class="currency-name">{{ currency }}</div>
              <div class="currency-amount">{{ formatCurrency(amount, currency) }}</div>
            </div>
          </el-col>
        </el-row>
      </div>
    </el-card>

    <!-- 额度统计 -->
    <el-card v-if="creditCardCount > 0" class="limit-stats-card">
      <template #header>
        <div class="card-header collapse-header" @click="collapsedPanels.limitStats = !collapsedPanels.limitStats">
          <div style="display: flex; align-items: center; gap: 8px;">
            <span>💳 信用卡额度统计分析</span>
            <el-tooltip content="根据是否共享额度进行智能统计">
              <el-icon @click.stop><QuestionFilled /></el-icon>
            </el-tooltip>
          </div>
          <div class="header-actions">
            <span class="fold-text">{{ collapsedPanels.limitStats ? '展开' : '收起' }}</span>
            <el-icon :class="{ 'is-collapsed': collapsedPanels.limitStats }" class="fold-arrow">
              <ArrowDown />
            </el-icon>
          </div>
        </div>
      </template>
      <div v-show="!collapsedPanels.limitStats" class="limit-stats">
        <el-row :gutter="20">
          <el-col :xs="24" :lg="12">
            <div class="limit-section">
              <h4>💼 共享额度银行</h4>
              <el-pagination v-if="sharedLimitStats.length > 50" v-model:current-page="sharedLimitStatsPage" :page-size="50" :total="sharedLimitStats.length" layout="prev, pager, next" small class="wallet-pagination" />
              <div v-if="sharedLimitStats.length === 0" class="empty-state">
                暂无共享额度的银行
              </div>
              <div v-else class="limit-list">
                <div v-for="item in sharedLimitStatsRows" :key="item.key" class="limit-item shared">
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
              <el-pagination v-if="independentLimitStats.length > 50" v-model:current-page="independentLimitStatsPage" :page-size="50" :total="independentLimitStats.length" layout="prev, pager, next" small class="wallet-pagination" />
              <div v-if="independentLimitStats.length === 0" class="empty-state">
                暂无独立额度的卡片
              </div>
              <div v-else class="limit-list">
                <div v-for="item in independentLimitStatsRows" :key="item.key" class="limit-item independent">
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
                  <span>📈 信用卡提额分析</span>
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
    <el-card v-if="creditCardCount > 0" class="annual-fee-card">
      <template #header>
        <div class="card-header collapse-header" @click="collapsedPanels.annualFeeStats = !collapsedPanels.annualFeeStats">
          <span>⏰ 信用卡年费状态分析</span>
          <div class="header-actions">
            <span class="fold-text">{{ collapsedPanels.annualFeeStats ? '展开' : '收起' }}</span>
            <el-icon :class="{ 'is-collapsed': collapsedPanels.annualFeeStats }" class="fold-arrow">
              <ArrowDown />
            </el-icon>
          </div>
        </div>
      </template>
      <div v-show="!collapsedPanels.annualFeeStats">
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
      </div>
    </el-card>

    <!-- 分布图表 -->
    <el-row :gutter="20">
      <el-col :xs="24" :lg="12">
        <el-card class="chart-card">
          <template #header>
            <div class="card-header collapse-header" @click="toggleBankChart">
              <span>🏦 银行分布</span>
              <div class="header-actions">
                <span class="fold-text">{{ collapsedPanels.bankChart ? '展开' : '收起' }}</span>
                <el-icon :class="{ 'is-collapsed': collapsedPanels.bankChart }" class="fold-arrow">
                  <ArrowDown />
                </el-icon>
              </div>
            </div>
          </template>
          <div v-show="!collapsedPanels.bankChart" ref="bankChart" class="chart"></div>
        </el-card>
      </el-col>
      <el-col :xs="24" :lg="12">
        <el-card class="chart-card">
          <template #header>
            <div class="card-header collapse-header" @click="toggleCountryChart">
              <span>🌍 国家分布</span>
              <div class="header-actions">
                <span class="fold-text">{{ collapsedPanels.countryChart ? '展开' : '收起' }}</span>
                <el-icon :class="{ 'is-collapsed': collapsedPanels.countryChart }" class="fold-arrow">
                  <ArrowDown />
                </el-icon>
              </div>
            </div>
          </template>
          <div v-show="!collapsedPanels.countryChart" ref="countryChart" class="chart"></div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 详细数据表格 -->
    <el-card class="table-card">
      <template #header>
        <div class="card-header collapse-header" @click="collapsedPanels.detailedTable = !collapsedPanels.detailedTable">
          <span>📊 详细数据分析</span>
          <div class="header-actions">
            <el-button type="primary" size="small" @click.stop="exportData">
              <el-icon><Download /></el-icon>
              导出数据
            </el-button>
            <span class="fold-text" style="margin-left: 10px;">{{ collapsedPanels.detailedTable ? '展开' : '收起' }}</span>
            <el-icon :class="{ 'is-collapsed': collapsedPanels.detailedTable }" class="fold-arrow">
              <ArrowDown />
            </el-icon>
          </div>
        </div>
      </template>
      <div v-show="!collapsedPanels.detailedTable">
        <el-table :data="detailedStatsRows" stripe>
          <el-table-column prop="country" label="国家" width="100" />
          <el-table-column prop="bank" label="银行" width="150" />
          <el-table-column prop="currency" label="币种" width="80" />
          <el-table-column prop="cardCount" label="卡片数" width="80" align="right" />
          <el-table-column prop="sharedType" label="额度类型" width="100">
            <template #default="{ row }">
              <el-tag v-if="row.isShared" type="success" size="small">共享</el-tag>
              <template v-else>
                <el-tag type="info" size="small">独立</el-tag>
              </template>
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
        <el-pagination v-if="detailedStats.length > 50" v-model:current-page="detailedStatsPage" :page-size="50" :total="detailedStats.length" layout="prev, pager, next" class="wallet-pagination" />
      </div>
    </el-card>
    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, nextTick, watch, inject } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { QuestionFilled, Download, WarningFilled, Clock, Check, ArrowDown } from '@element-plus/icons-vue'
import * as echarts from 'echarts/core'
import { PieChart } from 'echarts/charts'
import { TooltipComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'
import { creditLimitMetrics, formatCreditAmount, sharedLimitKey } from '@/utils/cardMetrics'
import { toCSV } from '@/utils/safeExport'
import { usePagedCards } from '@/composables/usePagedCards'
echarts.use([PieChart, TooltipComponent, CanvasRenderer])
import {
  AnnualFeeReminderKind,
  getAnnualFeeDetection,
  getCardExpiryStats
} from '@/utils/cardReminderRules'

// Props
const props = defineProps({
  cardData: {
    type: Array,
    required: true,
    default: () => []
  }
})

// 响应式数据
const isReady = ref(false)
const loading = ref(true)
const bankChart = ref(null)
const countryChart = ref(null)

const collapsedPanels = ref({
  debitDistribution: false,
  expiryStats: false,
  creditTotals: false,
  limitStats: false,
  annualFeeStats: false,
  bankChart: false,
  countryChart: false,
  detailedTable: false
})

const normalizeCardCategory = (card) => card?.cardCategory === 'debit' ? 'debit' : 'credit'

// 选择过滤类别与过滤后的数据
const selectedCategory = ref('all')
const creditCountAll = computed(() => props.cardData.filter(card => normalizeCardCategory(card) === 'credit').length)
const debitCountAll = computed(() => props.cardData.filter(card => normalizeCardCategory(card) === 'debit').length)
const filteredCardData = computed(() => {
  if (selectedCategory.value === 'all') {
    return props.cardData
  }
  return props.cardData.filter(card => normalizeCardCategory(card) === selectedCategory.value)
})

const creditCards = computed(() => filteredCardData.value.filter(card => normalizeCardCategory(card) === 'credit'))
const debitCards = computed(() => filteredCardData.value.filter(card => normalizeCardCategory(card) === 'debit'))

// 货币格式化
const formatCurrency = formatCreditAmount

// 基础统计
const totalCards = computed(() => filteredCardData.value.length)
const creditCardCount = computed(() => creditCards.value.length)
const debitCardCount = computed(() => debitCards.value.length)

const totalBanks = computed(() => {
  const banks = new Set(filteredCardData.value.map(card => card.bank || ''))
  return banks.size
})

const totalCountries = computed(() => {
  const countries = new Set(filteredCardData.value.map(card => card.country))
  return countries.size
})

const totalCurrencies = computed(() => {
  const currencies = new Set(filteredCardData.value.map(card => card.type))
  return currencies.size
})

const debitCountryCount = computed(() => new Set(debitCards.value.map(card => card.country).filter(Boolean)).size)
const debitBankCount = computed(() => new Set(debitCards.value.map(card => card.bank).filter(Boolean)).size)
const debitCurrencyCount = computed(() => new Set(debitCards.value.map(card => card.type).filter(Boolean)).size)

// 额度统计分析（考虑共享额度）
const limitMetrics = computed(() => creditLimitMetrics(creditCards.value))
const sharedLimitStats = computed(() => [...limitMetrics.value.shared].sort((a, b) => b.totalLimit - a.totalLimit))
const independentLimitStats = computed(() => [...limitMetrics.value.independent].sort((a, b) => b.limit - a.limit))
const currencyTotals = computed(() => Object.fromEntries(limitMetrics.value.totals.map(item => [item.currency || '未设置币种', item.amount])))

// 年费状态统计
const annualFeeStats = computed(() => {
  day.value
  let qualified = 0, unqualified = 0, warning = 0, lifetime = 0
  
  creditCards.value.forEach(card => {
    if (card.isQualified === '1') qualified++
    else if (card.isQualified === '2') unqualified++
    else if (card.isQualified === '3') lifetime++
    
    const reminder = getAnnualFeeDetection(card)
    if (reminder?.kind === AnnualFeeReminderKind.WARNING) warning++
  })
  
  return { qualified, unqualified, warning, lifetime }
})

// 卡片等级分布统计
const levelStats = computed(() => {
  const levelMap = new Map()
  
  creditCards.value.forEach(card => {
    const level = card.level || '未知'
    levelMap.set(level, (levelMap.get(level) || 0) + 1)
  })
  
  const total = filteredCardData.value.length
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
  return creditCards.value.reduce((total, card) => {
    return total + (parseFloat(card.annualFee) || 0)
  }, 0)
})

const avgAnnualFee = computed(() => {
  return creditCards.value.length > 0 ? Math.round(totalAnnualFee.value / creditCards.value.length) : 0
})

const freeAnnualFeeCards = computed(() => {
  return creditCards.value.filter(card => 
    parseFloat(card.annualFee) === 0 || card.isQualified === '3'
  ).length
})

// 卡片有效期分析
const day = inject('calendarDay', ref(Date.now()))
const expiryStats = computed(() => {
  day.value
  return getCardExpiryStats(filteredCardData.value)
})

const hasExpiryStats = computed(() => {
  return expiryStats.value.expiredCards > 0 ||
    expiryStats.value.soonExpiring > 0 ||
    expiryStats.value.normalCards > 0
})

// 提额分析统计
const raiseLimitStats = computed(() => {
  day.value
  const now = new Date()
  const sixMonthsAgo = new Date()
  sixMonthsAgo.setMonth(now.getMonth() - 6)
  const oneYearAgo = new Date()
  oneYearAgo.setFullYear(now.getFullYear() - 1)
  
  let recent6Months = 0, recent1Year = 0, never = 0
  
  filteredCardData.value.forEach(card => {
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
    const key = sharedLimitKey({ ...item, type: item.currency })
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

const { page: sharedLimitStatsPage, rows: sharedLimitStatsRows } = usePagedCards(sharedLimitStats, 50)

const { page: independentLimitStatsPage, rows: independentLimitStatsRows } = usePagedCards(independentLimitStats, 50)

const { page: detailedStatsPage, rows: detailedStatsRows } = usePagedCards(detailedStats, 50)

// 初始化图表
const initCharts = async () => {
  loading.value = true
  
  try {

    
    await nextTick()
    if (disposed) return
    
    const isDark = document.documentElement.classList.contains('dark')
    const textColor = isDark ? '#cbd5e1' : '#1e293b'

    // 银行分布图表
    if (bankChart.value) {
      let bankInstance = echarts.getInstanceByDom(bankChart.value)
      if (!bankInstance) {
        bankInstance = echarts.init(bankChart.value)
      }
      const bankData = Object.create(null)
      filteredCardData.value.forEach(card => {
        const bank = card.bank || ''
        bankData[bank] = (bankData[bank] || 0) + 1
      })
      
      const bankChartData = Object.entries(bankData)
        .sort((a, b) => b[1] - a[1])
        .map(([name, value]) => ({ name, value }))
      
      bankInstance.setOption({
        tooltip: {
          trigger: 'item',
          renderMode: 'richText',
          formatter: '{b}: {c} 张 ({d}%)'
        },
        series: [{
          type: 'pie',
          radius: ['40%', '70%'],
          data: bankChartData,
          label: {
            show: true,
            color: textColor,
            backgroundColor: 'transparent',
            textBorderColor: 'transparent',
            textBorderWidth: 0,
            textShadowColor: 'transparent',
            textShadowBlur: 0,
            formatter: '{b}: {c}张'
          },
          emphasis: {
            itemStyle: {
              shadowBlur: 10,
              shadowOffsetX: 0,
              shadowColor: 'rgba(0, 0, 0, 0.5)'
            }
          }
        }]
      }, true)
    }
    
    // 国家分布图表
    if (countryChart.value) {
      let countryInstance = echarts.getInstanceByDom(countryChart.value)
      if (!countryInstance) {
        countryInstance = echarts.init(countryChart.value)
      }
      const countryData = Object.create(null)
      filteredCardData.value.forEach(card => {
        countryData[card.country] = (countryData[card.country] || 0) + 1
      })
      
      const countryChartData = Object.entries(countryData)
        .sort((a, b) => b[1] - a[1])
        .map(([name, value]) => ({ name, value }))
      
      countryInstance.setOption({
        tooltip: {
          trigger: 'item',
          renderMode: 'richText',
          formatter: '{b}: {c} 张 ({d}%)'
        },
        series: [{
          type: 'pie',
          radius: ['40%', '70%'],
          data: countryChartData,
          label: {
            show: true,
            color: textColor,
            backgroundColor: 'transparent',
            textBorderColor: 'transparent',
            textBorderWidth: 0,
            textShadowColor: 'transparent',
            textShadowBlur: 0,
            formatter: '{b}: {c}张'
          },
          emphasis: {
            itemStyle: {
              shadowBlur: 10,
              shadowOffsetX: 0,
              shadowColor: 'rgba(0, 0, 0, 0.5)'
            }
          }
        }]
      }, true)
    }
  } finally {
    loading.value = false
  }
}

// 展开/折叠图表时的 resize 逻辑
const toggleBankChart = () => {
  collapsedPanels.value.bankChart = !collapsedPanels.value.bankChart
  if (!collapsedPanels.value.bankChart) {
    nextTick(() => {
      const chartDom = bankChart.value
      if (chartDom) {
        const instance = echarts.getInstanceByDom(chartDom)
        if (instance) {
          instance.resize()
        }
      }
    })
  }
}

const toggleCountryChart = () => {
  collapsedPanels.value.countryChart = !collapsedPanels.value.countryChart
  if (!collapsedPanels.value.countryChart) {
    nextTick(() => {
      const chartDom = countryChart.value
      if (chartDom) {
        const instance = echarts.getInstanceByDom(chartDom)
        if (instance) {
          instance.resize()
        }
      }
    })
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
  
  const csv = toCSV(data, ['国家', '银行', '币种', '卡片数', '额度类型', '总额度', '平均额度'])
  
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const link = document.createElement('a')
  link.href = URL.createObjectURL(blob)
  link.download = `银行卡统计分析_${new Date().toISOString().split('T')[0]}.csv`
  link.click()
  setTimeout(() => URL.revokeObjectURL(link.href), 0)
  
  ElMessage.success('数据导出成功')
}

let resizeHandler = null
let readyTimer = null
let disposed = false

onMounted(() => {
  readyTimer = setTimeout(async () => {
    isReady.value = true
    await nextTick()
    if (disposed) return
    await initCharts()
  }, 100)
  
  resizeHandler = () => {
    if (bankChart.value) {
      const bankInstance = echarts.getInstanceByDom(bankChart.value)
      if (bankInstance) bankInstance.resize()
    }
    if (countryChart.value) {
      const countryInstance = echarts.getInstanceByDom(countryChart.value)
      if (countryInstance) countryInstance.resize()
    }
  }
  window.addEventListener('resize', resizeHandler)
})

onBeforeUnmount(() => {
  disposed = true
  clearTimeout(readyTimer)
  for (const element of [bankChart.value, countryChart.value]) {
    if (element) echarts.getInstanceByDom(element)?.dispose()
  }
  if (resizeHandler) {
    window.removeEventListener('resize', resizeHandler)
  }
})

const theme = inject('theme', null)
if (theme) watch(theme.isDarkMode, () => initCharts())
watch([() => props.cardData.map(({ bank, country }) => `${bank}\0${country}`), selectedCategory], () => {
  initCharts()
})
</script>

<style scoped>
.statistics-container {
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 20px;
  min-height: 400px;
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
  }

  .limit-section h4 {
    margin-bottom: 16px;
    color: var(--el-text-color-primary);
    font-size: 16px;
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

.statistics-filter-wrapper {
  display: flex;
  justify-content: center;
  margin-bottom: 8px;
  width: 100%;

  .tech-radio-group {
    background: var(--el-fill-color-light);
    padding: 3px;
    border-radius: 30px;
    border: 1px solid var(--el-border-color-lighter);
    display: inline-flex;
    gap: 4px;

    :deep(.el-radio-button__inner) {
      border-radius: 20px !important;
      border: none !important;
      font-size: 13px !important;
      font-weight: 600 !important;
      padding: 6px 18px !important;
      height: auto !important;
      line-height: 1.2 !important;
      box-shadow: none !important;
      background: transparent !important;
      color: var(--el-text-color-regular) !important;
      transition: all 0.25s ease !important;

      &:hover {
        color: var(--el-text-color-primary) !important;
      }
    }

    :deep(.el-radio-button__original-radio:checked + .el-radio-button__inner) {
      background: var(--el-color-primary-light-8) !important;
      color: var(--el-color-primary) !important;
      box-shadow: none !important;
    }
  }
}

:global(html.dark) {
  .statistics-filter-wrapper {
    .tech-radio-group {
      :deep(.el-radio-button__original-radio:checked + .el-radio-button__inner) {
        background: rgba(0, 242, 254, 0.15) !important;
        color: #00f2fe !important;
        text-shadow: 0 0 6px rgba(0, 242, 254, 0.3) !important;
      }
    }
  }
}

.collapse-header {
  cursor: pointer;
  user-select: none;
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: var(--el-text-color-secondary);
}

.fold-text {
  font-weight: normal;
}

.fold-arrow {
  transition: transform 0.3s ease;
  font-size: 14px;
}

.fold-arrow.is-collapsed {
  transform: rotate(-90deg);
}
</style>
