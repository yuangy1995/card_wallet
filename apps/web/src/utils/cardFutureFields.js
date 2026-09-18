// Forward fields are opaque JSON, not editable UI or a new sync protocol.
const transient = new Set(["showCardNumber", "showCVV", "countryRowSpan", "showCountry", "bankRowSpan", "showBank", "limitRowSpan", "showLimit", "lastTimeRowSpan", "showLastTime", "cardId", "uuid", "legacyId", "annualFeeDate", "extraFields", "constructor", "prototype"])
export const allowedCardField = name => !name.startsWith('_') && !transient.has(name)
export const futureCardFields = (value, known) => Object.fromEntries(
  Object.entries(value).filter(([name]) => !known.has(name) && allowedCardField(name))
)
