import { describe, it, expect } from 'vitest';
import { formatDate, daysBetween } from '@/utils/dateUtils';

describe('dateUtils', () => {
  describe('formatDate', () => {
    it('应该正确格式化有效日期字符串', () => {
      const result = formatDate('2023-01-15T08:30:00');
      // 使用正则表达式匹配，因为不同环境下可能有细微差别
      expect(result).toMatch(/2023[\/-]01[\/-]15 08:30:00/);
    });

    it('应该返回破折号当输入为空', () => {
      expect(formatDate('')).toBe('-');
      expect(formatDate(null)).toBe('-');
      expect(formatDate(undefined)).toBe('-');
    });

    it('应该返回破折号当输入是无效日期', () => {
      expect(formatDate('not-a-date')).toBe('-');
    });
  });

  describe('daysBetween', () => {
    it('应该正确计算两个日期之间的天数', () => {
      expect(daysBetween('2023-01-01', '2023-01-10')).toBe(9);
      expect(daysBetween('2023-01-10', '2023-01-01')).toBe(9); // 顺序不影响结果
    });

    it('应该处理相同日期', () => {
      expect(daysBetween('2023-01-01', '2023-01-01')).toBe(0);
    });

    it('应该处理无效输入', () => {
      expect(daysBetween(null, '2023-01-01')).toBe(0);
      expect(daysBetween('2023-01-01', null)).toBe(0);
      expect(daysBetween('invalid', '2023-01-01')).toBe(0);
    });
  });
});
