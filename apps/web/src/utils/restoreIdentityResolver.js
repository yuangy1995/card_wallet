export const RESTORE_IDENTITY_DECISIONS = {
  KEEP_CURRENT: 'keep-current',
  KEEP_INCOMING: 'keep-incoming',
  KEEP_SEPARATE: 'keep-separate'
}

export const cardNumberFingerprint = (cardNumber = '') =>
  String(cardNumber).replace(/\D/g, '')

const defaultCreateId = () => globalThis.crypto?.randomUUID?.() ||
  `${Date.now()}-${Math.random().toString(16).slice(2)}`

export const resolveRestoreIdentityConflicts = async (
  incomingCards,
  existingCards,
  decide,
  { createId = defaultCreateId } = {}
) => {
  const existingById = new Map()
  const existingByFingerprint = new Map()

  ;(existingCards || []).forEach((card) => {
    if (card?.id) {
      existingById.set(card.id, card)
    }
    const fingerprint = cardNumberFingerprint(card?.cardNumber)
    if (fingerprint.length >= 8 && !existingByFingerprint.has(fingerprint)) {
      existingByFingerprint.set(fingerprint, card)
    }
  })

  const order = []
  const resolvedById = new Map()

  const appendOrReplace = (card) => {
    const cardToStore = { ...card }
    if (!cardToStore.id) {
      cardToStore.id = nextId()
    }
    if (!resolvedById.has(cardToStore.id)) {
      order.push(cardToStore.id)
    }
    resolvedById.set(cardToStore.id, cardToStore)
  }

  const nextId = () => {
    let candidate = createId()
    const usedIds = new Set([...existingById.keys(), ...resolvedById.keys()])
    while (!candidate || usedIds.has(candidate)) {
      candidate = createId()
    }
    return candidate
  }

  for (const incoming of incomingCards || []) {
    if (!incoming?.id || existingById.has(incoming.id)) {
      appendOrReplace(incoming)
      continue
    }

    const fingerprint = cardNumberFingerprint(incoming.cardNumber)
    const existing = fingerprint.length >= 8
      ? existingByFingerprint.get(fingerprint)
      : null

    if (!existing) {
      appendOrReplace(incoming)
      continue
    }

    const decision = await decide({ incoming, existing })
    if (!decision) {
      return null
    }

    if (decision === RESTORE_IDENTITY_DECISIONS.KEEP_CURRENT) {
      appendOrReplace(existing)
    } else if (decision === RESTORE_IDENTITY_DECISIONS.KEEP_INCOMING) {
      appendOrReplace({ ...incoming, id: existing.id })
    } else if (decision === RESTORE_IDENTITY_DECISIONS.KEEP_SEPARATE) {
      appendOrReplace(existing)
      appendOrReplace({ ...incoming, id: nextId() })
    }
  }

  return order.map((id) => resolvedById.get(id)).filter(Boolean)
}
