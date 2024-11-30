<template>
  <div class="statistics-container">
    <el-card class="overview-section">
      <div class="overview-grid">
        <div class="stat-item">
          <div class="stat-title">信用卡总数</div>
          <div class="stat-value">{{ totalCards }}</div>
        </div>
        <div class="stat-item">
          <div class="stat-title">人民币总额度</div>
          <div class="stat-value">¥{{ formatNumber(totalLimitCNY) }}</div>
        </div>
        <div v-for="(limit, currency) in otherCurrencyLimits" :key="currency" class="stat-item">
          <div class="stat-title">{{ currency }}总额度</div>
          <div class="stat-value">{{ currency }} {{ formatNumber(limit) }}</div>
        </div>
        <div class="stat-item">
          <div class="stat-title">待处理年费卡数</div>
          <div class="stat-value">{{ cardsNeedAnnualFee }}</div>
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

    <el-card class="annual-fee-section">
      <template #header>
        <div class="card-header">
          <span>年费状态</span>
        </div>
      </template>
      <el-table :data="annualFeeCards" style="width: 100%">
        <el-table-column prop="name" label="卡片名称" />
        <el-table-column prop="bank" label="发卡行" />
        <el-table-column prop="annualFee" label="年费">
          <template #default="scope">
            ¥{{ formatNumber(scope.row.annualFee) }}
          </template>
        </el-table-column>
        <el-table-column prop="dueDate" label="处理截止日">
          <template #default="scope">
            {{ new Date(scope.row.dueDate).toLocaleDateString() }}
          </template>
        </el-table-column>
        <el-table-column prop="status" label="状态">
          <template #default="scope">
            <el-tag :type="scope.row.status === '待处理' ? 'warning' : 'success'">
              {{ scope.row.status }}
            </el-tag>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue'
import * as echarts from 'echarts'

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

    const totalCards = ref(0)
    const totalLimitCNY = ref(0)
    const otherCurrencyLimits = ref({})
    const cardsNeedAnnualFee = ref(0)
    const annualFeeCards = ref([])

    const formatNumber = (num) => {
      return new Intl.NumberFormat('zh-CN').format(num)
    }

    const formatBankName = (bank) => {
      return bank.split('(')[0].trim()
    }

    const initCharts = () => {
      const cards = props.cardData
      totalCards.value = cards.length

      // 计算各币种总额度
      const currencyLimits = {}
      cards.forEach(card => {
        const currency = card.currency || 'CNY'
        const limit = Number(card.limit) || 0
        currencyLimits[currency] = (currencyLimits[currency] || 0) + limit
      })

      // 设置人民币总额度
      totalLimitCNY.value = currencyLimits['CNY'] || 0
      
      // 设置其他币种总额度
      const otherLimits = { ...currencyLimits }
      delete otherLimits['CNY']
      otherCurrencyLimits.value = otherLimits

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

      // 统计年费情况
      const now = new Date()
      const sixtyDaysLater = new Date(now.getTime() + 60 * 24 * 60 * 60 * 1000)
      annualFeeCards.value = cards
        .filter(card => {
          const annualFeeDate = new Date(card.annualFeeDate)
          return annualFeeDate <= sixtyDaysLater && !card.annualFeePaid
        })
        .map(card => ({
          name: card.name,
          bank: formatBankName(card.bank),
          annualFee: card.annualFee,
          dueDate: card.annualFeeDate,
          status: '待处理'
        }))
      cardsNeedAnnualFee.value = annualFeeCards.value.length
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

    onMounted(() => {
      // 等待 DOM 渲染完成
      setTimeout(() => {
        initCharts()
        window.addEventListener('resize', () => {
          const charts = [
            bankChart.value,
            levelChart.value
          ]
          charts.forEach(chart => {
            const instance = echarts.getInstanceByDom(chart)
            instance && instance.resize()
          })
        })
      }, 0)
    })

    return {
      totalCards,
      totalLimitCNY,
      otherCurrencyLimits,
      cardsNeedAnnualFee,
      annualFeeCards,
      bankChart,
      levelChart,
      formatNumber
    }
  }
}
</script>

<style scoped>
.statistics-container {
  padding: 20px;
}

.overview-section {
  margin-bottom: 20px;
}

.overview-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 20px;
}

.stat-item {
  text-align: center;
}

.stat-title {
  font-size: 16px;
  color: #666;
  margin-bottom: 8px;
}

.stat-value {
  font-size: 24px;
  font-weight: bold;
  color: #409EFF;
}

.chart-row {
  margin-bottom: 20px;
}

.chart-card {
  margin-bottom: 20px;
  height: 500px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.chart-container {
  height: calc(100% - 60px);
  padding: 10px;
}

.annual-fee-section {
  margin-top: 20px;
}
</style>
