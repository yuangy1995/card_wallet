<template>
  <div class="statistics-container">
    <el-card class="overview-section">
      <div class="overview-grid">
        <div class="stat-item">
          <div class="stat-title">信用卡总数</div>
          <div class="stat-value">{{ totalCards }}</div>
        </div>
        <div v-for="(limit, currency) in otherCurrencyLimits" :key="currency" class="stat-item">
          <div class="stat-title">{{ currency }}总额度</div>
          <div class="stat-value">{{ formatNumber(limit) }}</div>
        </div>
      </div>
    </el-card>

    <el-row :gutter="20" class="chart-row">
      <el-col :span="12">
        <el-card class="chart-card">
          <template #header>
            <div class="card-header">
              <span>银行分布</span>
            </div>
          </template>
          <div class="chart-container">
            <div ref="bankChart" style="height: 400px"></div>
          </div>
        </el-card>
      </el-col>

      <el-col :span="12">
        <el-card class="chart-card">
          <template #header>
            <div class="card-header">
              <span>卡片等级分布</span>
            </div>
          </template>
          <div class="chart-container">
            <div ref="levelChart" style="height: 400px"></div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-card class="box-card">
      <template #header>
        <div class="card-header">
          <span>年费处理情况</span>
        </div>
      </template>
      <div class="annual-fee-stats">
        <el-row :gutter="20">
          <el-col :span="6">
            <div class="stat-item">
              <div class="stat-title">总计年费卡片</div>
              <div class="stat-value">{{ totalAnnualFeeCards }}</div>
            </div>
          </el-col>
          <el-col :span="6">
            <div class="stat-item warning">
              <div class="stat-title">未达标</div>
              <div class="stat-value">{{ unqualifiedCards.length }}</div>
            </div>
          </el-col>
          <el-col :span="6">
            <div class="stat-item warning">
              <div class="stat-title">即将到期</div>
              <div class="stat-value">{{ warningCards.length }}</div>
            </div>
          </el-col>
          <el-col :span="6">
            <div class="stat-item danger">
              <div class="stat-title">已过期</div>
              <div class="stat-value">{{ overdueCards.length }}</div>
            </div>
          </el-col>
        </el-row>
      </div>
    </el-card>

    <el-dialog v-model="dialogVisible" title="统计分析" width="80%" :before-close="handleClose" draggable
      class="statistics-dialog">
      <!-- 统计卡片区域 -->
      <div class="statistics-cards">
        <el-row :gutter="20">
          <!-- 信用卡总数统计 -->
          <el-col :span="6">
            <el-card shadow="hover" class="stat-card">
              <div class="stat-title">信用卡总数</div>
              <div class="stat-value">{{ totalCards }}</div>
            </el-card>
          </el-col>
          <!-- 总额度统计 -->
          <el-col :span="6">
            <el-card shadow="hover" class="stat-card">
              <div class="stat-title">总额度统计</div>
              <div v-for="(limit, currency) in currencyLimits" :key="currency" class="stat-value">
                {{ currency }}: {{ formatNumber(limit) }}
              </div>
            </el-card>
          </el-col>
          <!-- 年费统计 -->
          <el-col :span="6">
            <el-card shadow="hover" class="stat-card" :class="annualFeeStatus.class">
              <div class="stat-title">年费状态</div>
              <div class="stat-value">{{ annualFeeStatus.text }}</div>
              <div class="stat-detail" v-if="annualFeeStatus.detail">
                {{ annualFeeStatus.detail }}
              </div>
            </el-card>
          </el-col>
          <!-- 银行分布 -->
          <el-col :span="6">
            <el-card shadow="hover" class="stat-card">
              <div class="stat-title">银行分布</div>
              <div class="stat-value">{{ bankCount }}家银行</div>
            </el-card>
          </el-col>
        </el-row>
      </div>

      <!-- 图表区域 -->
      <div class="charts-container">
        <el-row :gutter="20">
          <el-col :span="12">
            <div ref="bankDistributionChart" class="chart"></div>
          </el-col>
          <el-col :span="12">
            <div ref="currencyDistributionChart" class="chart"></div>
          </el-col>
        </el-row>
      </div>

      <!-- 额度明细表格 -->
      <div class="limits-detail">
        <h3>额度明细</h3>
        <el-table :data="bankLimitsData" style="width: 100%" border stripe>
          <el-table-column prop="bank" label="银行" />
          <el-table-column prop="currency" label="币种" width="100" />
          <el-table-column prop="cardCount" label="卡片数量" width="100" align="right" />
          <el-table-column label="总额度" width="200" align="right">
            <template #default="{ row }">
              {{ formatNumber(row.totalLimit) }}
            </template>
          </el-table-column>
        </el-table>
      </div>
    </el-dialog>
  </div>
</template>

<script>
import { ref, computed, onMounted, watch } from 'vue'
import * as echarts from 'echarts'
import { ElMessageBox, ElMessage } from 'element-plus'

export default {
  name: 'Statistics',
  props: {
    cardData: {
      type: Array,
      required: true,
      default: () => []
    }
  },
  setup(props) {
    const bankChart = ref(null)
    const levelChart = ref(null)
    const bankDistributionChart = ref(null)
    const currencyDistributionChart = ref(null)

    const totalCards = ref(0)
    const totalLimitCNY = ref(0)
    const otherCurrencyLimits = ref({})

    const formatNumber = (num) => {
      return new Intl.NumberFormat('zh-CN').format(num)
    }

    const formatBankName = (bank) => {
      return bank.split('(')[0].trim()
    }

    const initCharts = (data) => {
      const cards = data
      totalCards.value = cards.length

      // 计算各币种总额度
      const limits = {}
      const cnyBankLimits = new Map() // 用于存储中国境内各银行的最大额度

      cards.forEach(card => {
        const currency = card.type || '人民币'
        const limit = parseFloat(card.limit) || 0

        if (currency === '人民币') {
          if (card.country === '中国') {
            // 对于中国境内的卡片，按银行分组取最大额度
            const currentBankMax = cnyBankLimits.get(card.bank) || 0
            cnyBankLimits.set(card.bank, Math.max(currentBankMax, limit))
          } else {
            // 非中国境内的卡片直接累加
            limits[currency] = (limits[currency] || 0) + limit
          }
        } else if (limit > 0) { // 只统计额度大于0的外币卡
          limits[currency] = (limits[currency] || 0) + limit
        }
      })

      // 将中国境内各银行的最大额度加入到人民币总额中
      const domesticTotal = Array.from(cnyBankLimits.values()).reduce((sum, limit) => sum + limit, 0)
      if (domesticTotal > 0 || limits['人民币']) {
        limits['人民币'] = (limits['人民币'] || 0) + domesticTotal
      }

      // 更新统计数据
      totalLimitCNY.value = limits['人民币'] || 0
      delete limits['人民币']
      otherCurrencyLimits.value = limits

      // 统计银行分布
      const bankData = {}
      cards.forEach(card => {
        const bank = formatBankName(card.bank || '未知')
        bankData[bank] = (bankData[bank] || 0) + 1
      })

      // 统计卡片等级
      const levelData = {}
      cards.forEach(card => {
        const level = card.level || '未知'
        levelData[level] = (levelData[level] || 0) + 1
      })

      // 初始化图表
      initPieChart(bankChart.value, '银行分布', bankData)
      initPieChart(levelChart.value, '卡片等级分布', levelData)

      // 初始化统计分析图表
      initBankDistributionChart(bankDistributionChart.value, '银行分布', bankData)
      initCurrencyDistributionChart(currencyDistributionChart.value, '币种分布', limits)
    }

    const initPieChart = (el, title, data) => {
      if (!el) return
      const chart = echarts.init(el)
      const sortedData = Object.entries(data)
        .sort((a, b) => b[1] - a[1])
        .map(([name, value]) => ({
          name,
          value
        }))

      const option = {
        title: {
          text: title,
          left: 'center'
        },
        tooltip: {
          trigger: 'item',
          formatter: '{b}: {c} ({d}%)'
        },
        legend: {
          type: 'scroll',
          orient: 'vertical',
          right: 10,
          top: 20,
          bottom: 20,
        },
        series: [
          {
            type: 'pie',
            radius: ['40%', '70%'],
            center: ['40%', '50%'],
            avoidLabelOverlap: true,
            itemStyle: {
              borderRadius: 10,
              borderColor: '#fff',
              borderWidth: 2
            },
            label: {
              show: false
            },
            emphasis: {
              label: {
                show: true,
                fontSize: 14,
                fontWeight: 'bold'
              }
            },
            labelLine: {
              show: false
            },
            data: sortedData
          }
        ]
      }
      chart.setOption(option)
    }

    const initBankDistributionChart = (el, title, data) => {
      if (!el) return
      const chart = echarts.init(el)
      const sortedData = Object.entries(data)
        .sort((a, b) => b[1] - a[1])
        .map(([name, value]) => ({
          name,
          value
        }))

      const option = {
        title: {
          text: title,
          left: 'center'
        },
        tooltip: {
          trigger: 'item',
          formatter: '{b}: {c}张 ({d}%)'
        },
        series: [
          {
            type: 'pie',
            radius: '60%',
            data: sortedData,
            emphasis: {
              itemStyle: {
                shadowBlur: 10,
                shadowOffsetX: 0,
                shadowColor: 'rgba(0, 0, 0, 0.5)'
              }
            }
          }
        ]
      }
      chart.setOption(option)
    }

    const initCurrencyDistributionChart = (el, title, data) => {
      if (!el) return
      const chart = echarts.init(el)
      const sortedData = Object.entries(data)
        .sort((a, b) => b[1] - a[1])
        .map(([name, value]) => ({
          name,
          value
        }))

      const option = {
        title: {
          text: title,
          left: 'center'
        },
        tooltip: {
          trigger: 'item',
          formatter: '{b}: {c} ({d}%)'
        },
        series: [
          {
            type: 'pie',
            radius: '60%',
            data: sortedData,
            emphasis: {
              itemStyle: {
                shadowBlur: 10,
                shadowOffsetX: 0,
                shadowColor: 'rgba(0, 0, 0, 0.5)'
              }
            }
          }
        ]
      }
      chart.setOption(option)
    }

    // 计算属性
    const totalAnnualFeeCards = computed(() => {
      return props.cardData.filter(card => card.nextAnnualFeeCollectionTime && card.isQualified !== '3').length
    })

    const warningCards = ref([])
    const overdueCards = ref([])
    const unqualifiedCards = ref([])

    // 检测年费情况
    const checkAnnualFees = async () => {
      const now = new Date()
      warningCards.value = []
      overdueCards.value = []
      unqualifiedCards.value = []

      // 收集需要提醒的卡片
      for (const card of props.cardData) {
        if (!card.nextAnnualFeeCollectionTime || card.isQualified === '3') continue

        const dueDate = new Date(card.nextAnnualFeeCollectionTime)
        const diffDays = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24))

        // 未达标的卡片
        if (card.isQualified === '2' && diffDays > 0) {
          unqualifiedCards.value.push({ ...card, diffDays })
        }
        // 即将到期的卡片（不包括未达标的卡片）
        else if (diffDays <= 60 && diffDays > 0 && card.isQualified !== '2') {
          warningCards.value.push({ ...card, diffDays })
        }
        // 已过期的卡片
        else if (diffDays <= 0 && diffDays > -60) {
          overdueCards.value.push({ ...card, diffDays })
        }
      }

      // 如果有需要提醒的卡片，显示汇总弹窗
      if (warningCards.value.length > 0 || overdueCards.value.length > 0 || unqualifiedCards.value.length > 0) {
        // 构建提醒消息
        let message = '<div style="max-height: 400px; overflow-y: auto;">'

        if (unqualifiedCards.value.length > 0) {
          message += '<div style="margin-bottom: 16px;">'
          message += '<h3 style="color: #E6A23C; margin-bottom: 8px;">年费尚未达标</h3>'
          message += '<ul style="list-style-type: none; padding: 0; margin: 0; display: flex; flex-wrap: wrap; gap: 16px;">'
          unqualifiedCards.value.sort((a, b) => a.diffDays - b.diffDays).forEach(card => {
            message += `<li style="margin: 0; padding: 12px; background: #fdf6ec; border-radius: 4px; flex: 0 1 calc(33.33% - 12px); min-width: 200px; box-sizing: border-box;">
              <strong>${card.bank}${card.type}</strong><br />
              <strong>${card.alias}</strong>
              <div style="color: #666; margin-top: 4px;">距离年费收取还有 ${card.diffDays} 天</div>
            </li>`
          })
          message += '</ul></div>'
        }

        if (warningCards.value.length > 0) {
          message += '<div style="margin-bottom: 16px;">'
          message += '<h3 style="color: #E6A23C; margin-bottom: 8px;">即将到期年费提醒</h3>'
          message += '<ul style="list-style-type: none; padding: 0; margin: 0; display: flex; flex-wrap: wrap; gap: 16px;">'
          warningCards.value.sort((a, b) => a.diffDays - b.diffDays).forEach(card => {
            message += `<li style="margin: 0; padding: 12px; background: #fefce8; border-radius: 4px; flex: 0 1 calc(33.33% - 12px); min-width: 200px; box-sizing: border-box;">
              <strong>${card.bank}${card.type}</strong><br />
              <strong>${card.alias}</strong>
              <div style="color: #666; margin-top: 4px;">将在 ${card.diffDays} 天后收取年费</div>
            </li>`
          })
          message += '</ul></div>'
        }

        if (overdueCards.value.length > 0) {
          message += '<div style="margin-bottom: 16px;">'
          message += '<h3 style="color: #F56C6C; margin-bottom: 8px;">已过期年费提醒</h3>'
          message += '<ul style="list-style-type: none; padding: 0; margin: 0; display: flex; flex-wrap: wrap; gap: 16px;">'
          overdueCards.value.sort((a, b) => b.diffDays - a.diffDays).forEach(card => {
            message += `<li style="margin: 0; padding: 12px; background: #fef0f0; border-radius: 4px; flex: 0 1 calc(33.33% - 12px); min-width: 200px; box-sizing: border-box;">
              <strong>${card.bank}${card.type}</strong><br />
              <strong>${card.alias}</strong>
              <div style="color: #666; margin-top: 4px;">已过期 ${Math.abs(card.diffDays)} 天</div>
            </li>`
          })
          message += '</ul></div>'
        }

        message += '</div>'

        try {
          await ElMessageBox.alert(
            message,
            '年费提醒',
            {
              confirmButtonText: '知道了',
              dangerouslyUseHTMLString: true,
              customClass: 'annual-fee-dialog',
              showClose: false
            }
          )
        } catch (e) {
          // 忽略弹窗关闭事件
        }
      } else {
        ElMessage({
          type: 'success',
          message: '太好了！目前没有需要担心的年费问题',
          duration: 3000
        })
      }
    }

    // 在组件挂载时检查年费情况
    onMounted(() => {
      // 等待 DOM 渲染完成
      setTimeout(() => {
        initCharts(props.cardData)
        checkAnnualFees() // 自动检查年费情况

        // 添加图表resize监听
        window.addEventListener('resize', () => {
          const charts = [bankChart.value, levelChart.value]
          charts.forEach(chart => {
            const instance = echarts.getInstanceByDom(chart)
            instance && instance.resize()
          })
        })
      }, 100)
    })

    // 监听卡片数据变化
    watch(() => props.cardData, (newData) => {
      initCharts(newData)
      checkAnnualFees() // 当数据变化时重新检查年费情况
    }, { deep: true })

    // 统计分析相关数据
    const dialogVisible = ref(false)
    const cardCount = computed(() => props.cardData.length)
    const bankCount = computed(() => {
      const banks = new Set(props.cardData.map(card => card.bank))
      return banks.size
    })
    const currencyLimits = computed(() => {
      const limits = {}
      props.cardData.forEach(card => {
        const currency = card.type
        if (!limits[currency]) {
          limits[currency] = 0
        }
        limits[currency] += Number(card.limit) || 0
      })
      return limits
    })
    const annualFeeStatus = computed(() => {
      const now = new Date()
      let warningCount = 0
      let overdueCount = 0
      let unqualifiedCount = 0

      props.cardData.forEach(card => {
        if (!card.nextAnnualFeeCollectionTime) return

        const dueDate = new Date(card.nextAnnualFeeCollectionTime)
        const diffDays = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24))

        // 未达标的卡片
        if (card.isQualified === '2' && diffDays > 0) {
          unqualifiedCount++
        }
        // 即将到期的卡片（不包括未达标的卡片）
        else if (diffDays <= 60 && diffDays > 0 && card.isQualified !== '2') {
          warningCount++
        }
        // 已过期的卡片
        else if (diffDays <= 0 && diffDays > -60) {
          overdueCount++
        }
      })

      if (overdueCount > 0) {
        return {
          text: '需要注意',
          detail: `${overdueCount}张卡年费已过期`,
          class: 'danger'
        }
      } else if (warningCount > 0) {
        return {
          text: '即将到期',
          detail: `${warningCount}张卡年费即将到期`,
          class: 'warning'
        }
      } else if (unqualifiedCount > 0) {
        return {
          text: '未达标',
          detail: `${unqualifiedCount}张卡未达标`,
          class: 'warning'
        }
      } else {
        return {
          text: '正常',
          class: 'normal'
        }
      }
    })
    const bankLimitsData = computed(() => {
      const bankMap = new Map()

      props.cardData.forEach(card => {
        const key = `${card.bank}-${card.type}`
        if (!bankMap.has(key)) {
          bankMap.set(key, {
            bank: card.bank,
            currency: card.type,
            cardCount: 0,
            totalLimit: 0
          })
        }
        const bankData = bankMap.get(key)
        bankData.cardCount++
        bankData.totalLimit += Number(card.limit) || 0
      })

      return Array.from(bankMap.values())
        .sort((a, b) => {
          // 先按币种排序
          if (a.currency !== b.currency) {
            return a.currency.localeCompare(b.currency)
          }
          // 再按总额度降序排序
          return b.totalLimit - a.totalLimit
        })
    })

    const handleClose = () => {
      dialogVisible.value = false
    }

    return {
      totalCards,
      totalLimitCNY,
      otherCurrencyLimits,
      bankChart,
      levelChart,
      formatNumber,
      totalAnnualFeeCards,
      warningCards,
      overdueCards,
      unqualifiedCards,
      checkAnnualFees,
      dialogVisible,
      bankDistributionChart,
      currencyDistributionChart,
      cardCount,
      bankCount,
      currencyLimits,
      annualFeeStatus,
      bankLimitsData,
      handleClose
    }
  }
}
</script>

<style scoped>
.statistics-container {
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.overview-section {
  margin-bottom: 20px;
}

.overview-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 20px;
}

.chart-row {
  margin-bottom: 20px;
}

.chart-card {
  height: 100%;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.chart-container {
  height: 400px;
}

.annual-fee-stats {
  padding: 10px;
}

.stat-item {
  text-align: center;
  padding: 20px;
  border-radius: 8px;
  background-color: var(--el-fill-color-light);
  transition: all 0.3s ease;

  &.warning {
    background-color: #fefce8;

    .stat-title {
      color: #E6A23C;
    }
  }

  &.danger {
    background-color: #fef0f0;

    .stat-title {
      color: #F56C6C;
    }
  }

  .stat-title {
    font-size: 16px;
    color: var(--el-text-color-secondary);
    margin-bottom: 10px;
  }

  .stat-value {
    font-size: 24px;
    font-weight: bold;
    color: var(--el-text-color-primary);
  }
}

.statistics-dialog {
  :deep(.el-dialog__body) {
    padding: 20px;
  }
}

.statistics-cards {
  margin-bottom: 30px;
}

.stat-card {
  text-align: center;
  transition: transform 0.3s ease;

  &:hover {
    transform: translateY(-5px);
  }

  .stat-title {
    font-size: 16px;
    color: var(--el-text-color-secondary);
    margin-bottom: 10px;
  }

  .stat-value {
    font-size: 24px;
    font-weight: bold;
    color: var(--el-text-color-primary);
    margin-bottom: 5px;
  }

  .stat-detail {
    font-size: 14px;
    color: var(--el-text-color-secondary);
  }

  &.warning {
    .stat-value {
      color: var(--el-color-warning);
    }
  }

  &.danger {
    .stat-value {
      color: var(--el-color-danger);
    }
  }
}

.chart {
  height: 400px;
  margin-bottom: 30px;
}

.limits-detail {
  h3 {
    margin-bottom: 20px;
    color: var(--el-text-color-primary);
  }
}
</style>
