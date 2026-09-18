export const MAX_CARD_IMAGES = 12
export const MAX_SOURCE_BYTES = 10 * 1024 * 1024
export const canAppendImages = (existing, additional) => existing >= 0 && additional >= 0 && existing <= MAX_CARD_IMAGES && additional <= MAX_CARD_IMAGES - existing
export function normalizeCardImages(value) {
  if (value == null) return []
  if (!Array.isArray(value)) throw new Error('图片数据格式无法读取，原数据未被更改。')
  return value.map((item, index) => {
    if (typeof item === 'string') {
      return { id: crypto.randomUUID(), mimeType: item.match(/^data:([^;]+);/)?.[1] || 'image/jpeg', data: item,
        createdAt: Date.now(), source: 'legacy', name: `card_image_${index + 1}.jpg` }
    }
    if (!item || typeof item !== 'object') throw new Error('图片数据格式无法读取，原数据未被更改。')
    return { ...item, id: item.id || crypto.randomUUID(), mimeType: item.mimeType || 'image/jpeg', data: item.data || '',
      createdAt: Number(item.createdAt) || 0, source: item.source || 'manual', name: item.name || '' }
  })
}
export async function fileToCardImage(file) {
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type) || file.size > MAX_SOURCE_BYTES) {
    throw new Error('请选择不超过 10 MB 的 JPEG、PNG 或 WebP 图片。')
  }
  const url = URL.createObjectURL(file)
  try {
    const image = new Image()
    image.src = url
    await image.decode()
    const scale = Math.min(1, 1600 / Math.max(image.naturalWidth, image.naturalHeight))
    const canvas = document.createElement('canvas')
    canvas.width = Math.max(1, Math.round(image.naturalWidth * scale))
    canvas.height = Math.max(1, Math.round(image.naturalHeight * scale))
    const context = canvas.getContext('2d')
    context.fillStyle = '#ffffff'; context.fillRect(0, 0, canvas.width, canvas.height)
    context.drawImage(image, 0, 0, canvas.width, canvas.height)
    return { id: crypto.randomUUID(), mimeType: 'image/jpeg', data: canvas.toDataURL('image/jpeg', 0.84),
      createdAt: Date.now(), source: 'web_upload', name: file.name }
  } finally { URL.revokeObjectURL(url) }
}
