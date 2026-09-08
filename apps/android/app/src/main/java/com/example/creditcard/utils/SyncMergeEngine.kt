package com.example.creditcard.utils

import com.example.creditcard.data.CardSyncRecord
import com.example.creditcard.data.SharedCard

/**
 * 变动账本 CRDT 合流引擎（采用 LWW 最后写入优胜逻辑，保证三端合并完全无冲突）
 */
object SyncMergeEngine {

    private const val STATE_ACTIVE = "active"
    private const val STATE_DELETED = "deleted"

    /**
     * 比较两条针对同一张信用卡的变动记录，决出最后的“赢家”记录
     */
    fun winner(lhs: CardSyncRecord, rhs: CardSyncRecord): CardSyncRecord {
        // 1. 比较时间戳：最新时间的胜出。跨端输入可能缺少毫秒或携带时区，必须解析后比较。
        val timeComparison = SyncTime.compareIsoLike(lhs.changedAt, rhs.changedAt)
        if (timeComparison != 0) {
            return if (timeComparison > 0) lhs else rhs
        }

        // 2. 时间戳完全相同：deleted 状态（删除）优先胜出
        if (lhs.state != rhs.state) {
            return if (lhs.state == STATE_DELETED) lhs else rhs
        }

        // 3. 时间与状态均相同：以 mutationId 字典序大者打破僵局胜出
        return if (lhs.mutationId >= rhs.mutationId) lhs else rhs
    }

    /**
     * 合并多个账本数据，归口去重后输出唯一的赢家记录集合
     */
    fun merge(vararg collections: List<CardSyncRecord>): List<CardSyncRecord> {
        val winningRecords = HashMap<String, CardSyncRecord>()
        
        for (collection in collections) {
            for (rawRecord in collection) {
                val record = normalizeRecord(rawRecord) ?: continue
                val cardId = record.cardId
                
                val existing = winningRecords[cardId]
                if (existing != null) {
                    winningRecords[cardId] = winner(existing, record)
                } else {
                    winningRecords[cardId] = record
                }
            }
        }
        
        // 按 cardId 升序排列输出
        return winningRecords.values.sortedBy { it.cardId }
    }

    /**
     * 从合并后的账本记录中，过滤并还原出所有当前处于“活跃 (active)”状态的卡片对象
     */
    fun extractActiveCards(records: List<CardSyncRecord>): List<SharedCard> {
        return merge(records).filter { it.state == STATE_ACTIVE }
            .mapNotNull { it.card }
            .sortedBy { it.id }
    }

    fun normalizeRecord(record: CardSyncRecord): CardSyncRecord? {
        val cardId = record.cardId.trim()
        if (cardId.isEmpty()) return null

        val normalizedChangedAt = SyncTime.normalizeIso(record.changedAt)
        val normalizedState = if (record.state == STATE_DELETED) STATE_DELETED else STATE_ACTIVE
        val normalizedMutationId = record.mutationId.ifBlank { java.util.UUID.randomUUID().toString() }

        if (normalizedState == STATE_DELETED) {
            return CardSyncRecord(
                cardId = cardId,
                mutationId = normalizedMutationId,
                changedAt = normalizedChangedAt,
                state = STATE_DELETED,
                card = null
            )
        }

        val normalizedCard = normalizeCard(record.card ?: return null, cardId, normalizedChangedAt)

        return CardSyncRecord(
            cardId = cardId,
            mutationId = normalizedMutationId,
            changedAt = normalizedChangedAt,
            state = STATE_ACTIVE,
            card = normalizedCard
        )
    }

    private fun normalizeCard(card: SharedCard, cardId: String, changedAt: String): SharedCard {
        return card.copy(
            id = cardId,
            cardCategory = if (card.cardCategory == "debit") "debit" else "credit",
            type = card.type.trim(),
            lastModifyTime = SyncTime.parseMillis(changedAt) ?: SyncTime.nowMillis()
        )
    }
}
