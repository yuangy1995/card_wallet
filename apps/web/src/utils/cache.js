/**
 * 缓存管理工具
 */

/**
 * 内存缓存管理器
 */
export class MemoryCache {
  constructor(maxSize = 100, ttl = 5 * 60 * 1000) { // 默认5分钟过期
    this.cache = new Map()
    this.maxSize = maxSize
    this.ttl = ttl // 生存时间
  }

  /**
   * 设置缓存
   * @param {string} key - 缓存键
   * @param {any} value - 缓存值
   * @param {number} customTtl - 自定义过期时间
   */
  set(key, value, customTtl = null) {
    const expireTime = Date.now() + (customTtl || this.ttl)
    
    this.cache.delete(key)
    // 如果缓存已满，删除最旧的项
    if (this.cache.size >= this.maxSize) {
      const firstKey = this.cache.keys().next().value
      this.cache.delete(firstKey)
    }

    this.cache.set(key, {
      value,
      expireTime
    })
  }

  /**
   * 获取缓存
   * @param {string} key - 缓存键
   * @returns {any} 缓存值或null
   */
  get(key) {
    const item = this.cache.get(key)
    
    if (!item) return null

    // 检查是否过期
    if (Date.now() > item.expireTime) {
      this.cache.delete(key)
      return null
    }

    return item.value
  }

  /**
   * 删除缓存
   * @param {string} key - 缓存键
   */
  delete(key) {
    this.cache.delete(key)
  }

  /**
   * 清空所有缓存
   */
  clear() {
    this.cache.clear()
  }

  /**
   * 获取缓存大小
   */
  size() {
    return this.cache.size
  }

  /**
   * 清理过期缓存
   */
  cleanup() {
    const now = Date.now()
    for (const [key, item] of this.cache.entries()) {
      if (now > item.expireTime) {
        this.cache.delete(key)
      }
    }
  }
}

/**
 * 计算结果缓存装饰器
 * @param {number} ttl - 缓存时间
 */
export function cached(ttl = 5 * 60 * 1000) {
  const cache = new MemoryCache(50, ttl)
  
  return function(target, propertyKey, descriptor) {
    const originalMethod = descriptor.value

    descriptor.value = function(...args) {
      const cacheKey = `${propertyKey}_${JSON.stringify(args)}`
      
      // 尝试从缓存获取
      const cachedResult = cache.get(cacheKey)
      if (cachedResult !== null) {
        return cachedResult
      }

      // 执行原方法并缓存结果
      const result = originalMethod.apply(this, args)
      cache.set(cacheKey, result)
      
      return result
    }

    return descriptor
  }
}

/**
 * 全局缓存实例
 */
export const globalCache = new MemoryCache()

/**
 * 卡片数据计算缓存
 */
export class CardDataCache {
  constructor() {
    this.cache = new MemoryCache(200, 10 * 60 * 1000) // 10分钟缓存
  }

  /**
   * 获取缓存的年费状态
   */
  getAnnualFeeStatus(cardId, nextAnnualFeeTime) {
    const key = `annual_fee_${cardId}_${nextAnnualFeeTime}`
    return this.cache.get(key)
  }

  /**
   * 设置年费状态缓存
   */
  setAnnualFeeStatus(cardId, nextAnnualFeeTime, status) {
    const key = `annual_fee_${cardId}_${nextAnnualFeeTime}`
    this.cache.set(key, status)
  }

  /**
   * 获取缓存的免息期计算
   */
  getInterestFreePeriod(cardId, billingDay, repaymentDay) {
    const key = `interest_free_${cardId}_${billingDay}_${repaymentDay}`
    return this.cache.get(key)
  }

  /**
   * 设置免息期计算缓存
   */
  setInterestFreePeriod(cardId, billingDay, repaymentDay, period) {
    const key = `interest_free_${cardId}_${billingDay}_${repaymentDay}`
    this.cache.set(key, period)
  }

  /**
   * 清理指定卡片的缓存
   */
  clearCardCache(cardId) {
    for (const key of this.cache.cache.keys()) {
      if (key.includes(cardId)) {
        this.cache.delete(key)
      }
    }
  }

  /**
   * 清理所有缓存
   */
  clear() {
    this.cache.clear()
  }
}

// 全局卡片数据缓存实例
export const cardDataCache = new CardDataCache()
