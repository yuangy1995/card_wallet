<template>
  <div class="statistics-container">
    <el-card class="statistics-card">
      <template #header>
        <div class="card-header">
          <span>信用卡统计</span>
          <el-button type="primary" @click="refreshStatistics">刷新统计</el-button>
        </div>
      </template>
      
      <el-descriptions :column="2" border>
        <!-- 基本统计 -->
        <el-descriptions-item label="信用卡总数">
          {{ statistics.totalCards }}
        </el-descriptions-item>
        <el-descriptions-item label="总额度">
          {{ formatCurrency(statistics.totalLimit) }}
        </el-descriptions-item>
        <el-descriptions-item label="平均额度">
          {{ formatCurrency(statistics.averageLimit) }}
        </el-descriptions-item>
        <el-descriptions-item label="最高额度">
          {{ formatCurrency(statistics.maxLimit) }}
        </el-descriptions-item>

        <!-- 年费统计 -->
        <el-descriptions-item label="年费达标">
          <el-tag type="success">{{ statistics.qualifiedCount }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="年费未达标">
          <el-tag type="danger">{{ statistics.unqualifiedCount }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="终身免年费">
          <el-tag type="info">{{ statistics.lifetimeFreeCount }}</el-tag>
        </el-descriptions-item>
        <el-descriptions-item label="年费总额">
          {{ formatCurrency(statistics.totalAnnualFee) }}
        </el-descriptions-item>

        <!-- 币种统计 -->
        <el-descriptions-item label="币种分布" :span="2">
          <el-space wrap>
            <el-tag
              v-for="(count, type) in statistics.currencyTypes"
              :key="type"
              :type="getCurrencyTagType(type)"
            >
              {{ type }}: {{ count }}
            </el-tag>
          </el-space>
        </el-descriptions-item>

        <!-- 银行分布 -->
        <el-descriptions-item label="银行分布" :span="2">
          <el-space wrap>
            <el-tag
              v-for="(count, bank) in statistics.banks"
              :key="bank"
              type="info"
            >
              {{ bank }}: {{ count }}
            </el-tag>
          </el-space>
        </el-descriptions-item>
      </el-descriptions>

      <!-- 图表展示 -->
      <div class="charts-container">
        <div class="chart-item">
          <h4>额度分布</h4>
          <!-- 这里可以添加图表组件 -->
        </div>
        <div class="chart-item">
          <h4>银行占比</h4>
          <!-- 这里可以添加图表组件 -->
        </div>
      </div>
    </el-card>
  </div>
</template>

<script>
export default {
  name: 'CreditCardStatistics',

  props: {
    cardData: {
      type: Array,
      required: true,
      default: () => []
    }
  },

  data() {
    return {
      statistics: {
        totalCards: 0,
        totalLimit: 0,
        averageLimit: 0,
        maxLimit: 0,
        qualifiedCount: 0,
        unqualifiedCount: 0,
        lifetimeFreeCount: 0,
        totalAnnualFee: 0,
        currencyTypes: {},
        banks: {}
      }
    }
  },

  methods: {
    calculateStatistics() {
      // 重置统计数据
      this.statistics = {
        totalCards: 0,
        totalLimit: 0,
        averageLimit: 0,
        maxLimit: 0,
        qualifiedCount: 0,
        unqualifiedCount: 0,
        lifetimeFreeCount: 0,
        totalAnnualFee: 0,
        currencyTypes: {},
        banks: {}
      }

      // 基本统计
      this.statistics.totalCards = this.cardData.length
      
      // 遍历卡片数据进行统计
      this.cardData.forEach(card => {
        // 额度统计
        const limit = parseFloat(card.limit) || 0
        this.statistics.totalLimit += limit
        this.statistics.maxLimit = Math.max(this.statistics.maxLimit, limit)

        // 年费状态统计
        switch (card.isQualified) {
          case '1':
            this.statistics.qualifiedCount++
            break
          case '2':
            this.statistics.unqualifiedCount++
            break
          case '3':
            this.statistics.lifetimeFreeCount++
            break
        }

        // 年费统计
        this.statistics.totalAnnualFee += parseFloat(card.annualFee) || 0

        // 币种统计
        if (card.type) {
          this.statistics.currencyTypes[card.type] = (this.statistics.currencyTypes[card.type] || 0) + 1
        }

        // 银行统计
        if (card.bank) {
          this.statistics.banks[card.bank] = (this.statistics.banks[card.bank] || 0) + 1
        }
      })

      // 计算平均额度
      this.statistics.averageLimit = this.statistics.totalCards > 0
        ? this.statistics.totalLimit / this.statistics.totalCards
        : 0
    },

    refreshStatistics() {
      this.calculateStatistics()
      this.$emit('statistics-updated', this.statistics)
    },

    formatCurrency(value) {
      return new Intl.NumberFormat('zh-CN', {
        style: 'currency',
        currency: 'CNY',
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
      }).format(value)
    },

    getCurrencyTagType(type) {
      const typeMap = {
        'CNY': 'info',
        'USD': 'success',
        'EUR': 'warning',
        'GBP': 'danger',
        'HKD': 'primary',
        'JPY': 'info'
      }
      return typeMap[type] || 'info'
    }
  },

  mounted() {
    this.calculateStatistics()
  },

  watch: {
    cardData: {
      handler() {
        this.calculateStatistics()
      },
      deep: true
    }
  }
}
</script>

<style lang="scss" scoped>
.statistics-container {
  padding: 20px;

  .statistics-card {
    .card-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
  }

  .charts-container {
    margin-top: 20px;
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 20px;

    .chart-item {
      min-height: 300px;
      padding: 16px;
      border: 1px solid var(--el-border-color-light);
      border-radius: 4px;
    }

    .chart-item h4 {
      margin: 0 0 16px;
      color: var(--el-text-color-primary);
    }
  }
}

:deep(.el-descriptions) {
  margin-bottom: 20px;
}

:deep(.el-tag) {
  margin: 4px;
}

:deep(.el-space) {
  width: 100%;
  flex-wrap: wrap;
}
</style>
