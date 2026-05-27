import { describe, expect, it } from 'vitest'
import {
  RESTORE_IDENTITY_DECISIONS,
  resolveRestoreIdentityConflicts
} from './restoreIdentityResolver'

const card = (id, cardNumber, limit = 0) => ({
  id,
  country: '中国',
  bank: '东亚银行',
  cardNumber,
  limit
})

describe('restore identity resolver', () => {
  it('keeps current card when the user confirms same card and current data', async () => {
    const current = card('current-id', '6224000000005468', 50000)
    const incoming = card('generated-id', '6224 0000 0000 5468', 90000)

    const resolved = await resolveRestoreIdentityConflicts(
      [incoming],
      [current],
      async () => RESTORE_IDENTITY_DECISIONS.KEEP_CURRENT
    )

    expect(resolved).toHaveLength(1)
    expect(resolved[0]).toMatchObject({ id: 'current-id', limit: 50000 })
  })

  it('keeps incoming data under the current card identity', async () => {
    const current = card('current-id', '6224000000005468', 50000)
    const incoming = card('generated-id', '6224 0000 0000 5468', 90000)

    const resolved = await resolveRestoreIdentityConflicts(
      [incoming],
      [current],
      async () => RESTORE_IDENTITY_DECISIONS.KEEP_INCOMING
    )

    expect(resolved).toHaveLength(1)
    expect(resolved[0]).toMatchObject({ id: 'current-id', limit: 90000 })
  })

  it('keeps same-number cards separate with a fresh identity', async () => {
    const current = card('current-id', '6224000000005468', 50000)
    const incoming = card('generated-id', '6224 0000 0000 5468', 90000)

    const resolved = await resolveRestoreIdentityConflicts(
      [incoming],
      [current],
      async () => RESTORE_IDENTITY_DECISIONS.KEEP_SEPARATE,
      { createId: () => 'fresh-id' }
    )

    expect(resolved).toHaveLength(2)
    expect(resolved).toContainEqual(expect.objectContaining({ id: 'current-id', limit: 50000 }))
    expect(resolved).toContainEqual(expect.objectContaining({ id: 'fresh-id', limit: 90000 }))
    expect(resolved).not.toContainEqual(expect.objectContaining({ id: 'generated-id' }))
  })

  it('assigns an identity when restored data has no usable id', async () => {
    const incoming = card('', '6224000000005468', 90000)

    const resolved = await resolveRestoreIdentityConflicts(
      [incoming],
      [],
      async () => RESTORE_IDENTITY_DECISIONS.KEEP_INCOMING,
      { createId: () => 'fresh-id' }
    )

    expect(resolved).toHaveLength(1)
    expect(resolved[0]).toMatchObject({ id: 'fresh-id', limit: 90000 })
  })
})
