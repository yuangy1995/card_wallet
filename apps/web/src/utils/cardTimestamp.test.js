import { describe, expect, it, vi } from 'vitest'
import {
  formatCardTimestamp,
  formatTimestampForDateInput,
  normalizeCardTimeFields,
  timestampFromDateInput,
  toCardTimestamp
} from './cardTimestamp'

describe('card timestamp utilities', () => {
  it('normalizes legacy date strings to millisecond timestamps', () => {
    expect(toCardTimestamp('2026-05-27 01:23:45')).toBe(new Date(2026, 4, 27, 1, 23, 45).getTime())
    expect(toCardTimestamp('2026-05-27')).toBe(new Date(2026, 4, 27).getTime())
  })

  it('preserves millisecond timestamps and converts second timestamps', () => {
    expect(toCardTimestamp(1780000000000)).toBe(1780000000000)
    expect(toCardTimestamp('1780000000')).toBe(1780000000000)
  })

  it('formats timestamps for display and date inputs', () => {
    const timestamp = new Date(2026, 4, 27, 1, 2, 3).getTime()

    expect(formatCardTimestamp(timestamp)).toBe('2026/05/27 01:02:03')
    expect(formatTimestampForDateInput(timestamp)).toBe('2026-05-27')
    expect(timestampFromDateInput('2026-05-27')).toBe(new Date(2026, 4, 27).getTime())
  })

  it('fills missing last modify time when requested', () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-05-27T00:00:00.000Z'))

    const normalized = normalizeCardTimeFields({ id: 'one', lastTime: '2026-05-27' }, {
      fillLastModifyTime: true
    })

    expect(normalized.lastTime).toBe(new Date(2026, 4, 27).getTime())
    expect(normalized.lastModifyTime).toBe(Date.now())
    vi.useRealTimers()
  })
})
