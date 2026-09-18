<template>
  <el-dialog
    v-model="visible"
    title="优惠用卡"
    width="760px"
    top="6vh"
    :destroy-on-close="true"
    class="mobile-dialog best-usage-dialog"
  >
    <el-scrollbar max-height="72vh">
      <div class="best-usage-content">
        <el-alert
          title="根据今天的消费日期、账单日、还款日和账单日消费归属规则，实时计算当前可用免息期。"
          type="info"
          :closable="false"
          show-icon
        />

        <el-empty v-if="rankedCards.length === 0" description="暂无可用于免息期计算的信用卡" />

        <div v-else class="ranking-list">
          <div
            v-for="(item, index) in rankedRows"
            :key="item.card.id"
            class="ranking-card"
            :class="{ champion: page === 1 && index === 0 }"
          >
            <div class="rank-badge">{{ rankText((page - 1) * 50 + index) }}</div>
            <div class="card-summary">
              <strong>{{ displayName(item.card) }}</strong>
              <span>{{ item.card.country || '未设置地区' }} · {{ item.card.type || '未设置币种' }}</span>
              <span>账单日 {{ item.card.accountBillDate }} 日 · 还款日 {{ item.card.dueDate }} 日</span>
            </div>
            <div class="days-summary">
              <strong>{{ item.days }}</strong>
              <span>天免息期</span>
            </div>
            <el-button size="small" type="primary" plain @click="editCard(item.card)">配置</el-button>
          </div>
        </div>

        <el-pagination v-if="rankedCards.length > 50" v-model:current-page="page" :page-size="50" :total="rankedCards.length" layout="prev, pager, next" class="wallet-pagination" />
        <el-collapse v-if="invalidCards.length > 0" class="invalid-section">
          <el-collapse-item :title="`${invalidCards.length} 张信用卡尚未配置完整账单信息`" name="invalid">
            <div v-for="card in invalidRows" :key="card.id" class="invalid-card">
              <span>{{ displayName(card) }}</span>
              <el-button link type="primary" @click="editCard(card)">去配置</el-button>
            </div>
            <el-pagination v-if="invalidCards.length > 50" v-model:current-page="invalidPage" :page-size="50" :total="invalidCards.length" layout="prev, pager, next" class="wallet-pagination" />
          </el-collapse-item>
        </el-collapse>
      </div>
    </el-scrollbar>
  </el-dialog>
</template>

<script setup>
import { computed, ref, inject } from 'vue'
import { usePagedCards } from '@/composables/usePagedCards'
import { calculateCurrentInterestFreeDays } from '@/utils/dateCalculator'

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  cards: { type: Array, default: () => [] }
})

const emit = defineEmits(['update:modelValue', 'edit-card'])

const visible = computed({
  get: () => props.modelValue,
  set: value => emit('update:modelValue', value)
})

const creditCards = computed(() => props.cards.filter(card => card.cardCategory !== 'debit'))

const day = inject('calendarDay', ref(Date.now()))
const rankedCards = computed(() => creditCards.value
  .map(card => ({ card, days: calculateCurrentInterestFreeDays(card, new Date(day.value)) }))
  .filter(item => item.days >= 0)
  .sort((left, right) => right.days - left.days))

const invalidCards = computed(() => creditCards.value.filter(card => calculateCurrentInterestFreeDays(card, new Date(day.value)) < 0))

const { page, rows: rankedRows } = usePagedCards(rankedCards, 50)
const { page: invalidPage, rows: invalidRows } = usePagedCards(invalidCards, 50)

const displayName = card => [card.bank, card.alias].filter(Boolean).join(' · ') || '未命名信用卡'
const rankText = index => ['🥇', '🥈', '🥉'][index] || `#${index + 1}`

const editCard = card => {
  visible.value = false
  emit('edit-card', card)
}
</script>

<style scoped>
.best-usage-content,
.ranking-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.ranking-card {
  display: grid;
  grid-template-columns: 48px minmax(0, 1fr) 100px auto;
  align-items: center;
  gap: 14px;
  padding: 16px;
  border: 1px solid var(--el-border-color-light);
  border-radius: 14px;
  background: var(--el-bg-color-overlay);
}

.ranking-card.champion {
  border-color: var(--el-color-warning-light-5);
  background: linear-gradient(135deg, var(--el-color-warning-light-9), var(--el-bg-color-overlay));
}

.rank-badge { font-size: 26px; text-align: center; }
.card-summary, .days-summary { display: flex; flex-direction: column; gap: 4px; }
.card-summary span, .days-summary span { color: var(--el-text-color-secondary); font-size: 12px; }
.days-summary { align-items: center; }
.days-summary strong { color: var(--el-color-primary); font-size: 28px; line-height: 1; }
.invalid-section { margin-top: 4px; }
.invalid-card { display: flex; align-items: center; justify-content: space-between; padding: 6px 2px; }

@media (max-width: 640px) {
  .ranking-card { grid-template-columns: 40px 1fr auto; }
  .days-summary { grid-column: 2; align-items: flex-start; flex-direction: row; }
}
</style>
