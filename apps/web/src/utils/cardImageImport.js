export const IMAGE_LIMITS = Object.freeze({ count: 20, inputBytes: 10 * 1024 * 1024, storedBytes: 2 * 1024 * 1024, edge: 1600 })
export const canAppendImages = (existing, incoming) => Number.isInteger(existing) && Number.isInteger(incoming) && incoming > 0 && existing >= 0 && existing + incoming <= IMAGE_LIMITS.count
export const validateImageInput = file => {
  if (!file || !['image/jpeg','image/png','image/webp','image/gif'].includes(file.type) || file.size <= 0 || file.size > IMAGE_LIMITS.inputBytes) throw new Error('请使用不超过10MB的JPEG、PNG、WebP或GIF图片')
}
export async function importCardImage(file) {
  validateImageInput(file)
  // Browser decoding applies EXIF orientation. close() releases its backing pixels.
  const bitmap = await createImageBitmap(file)
  try {
    const scale = Math.min(1, IMAGE_LIMITS.edge / Math.max(bitmap.width, bitmap.height))
    const canvas = document.createElement('canvas')
    canvas.width = Math.max(1, Math.round(bitmap.width * scale)); canvas.height = Math.max(1, Math.round(bitmap.height * scale))
    const context = canvas.getContext('2d')
    if (!context) throw new Error('图片处理暂不可用')
    context.fillStyle = '#fff'; context.fillRect(0, 0, canvas.width, canvas.height)
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height)
    const data = canvas.toDataURL('image/jpeg', 0.84)
    if (Math.ceil(data.split(',')[1].length * 3 / 4) > IMAGE_LIMITS.storedBytes) throw new Error('压缩后的图片仍过大，请选择较小的图片')
    return { id: crypto.randomUUID(), mimeType: 'image/jpeg', data, createdAt: Date.now(), source: 'web_upload', name: file.name }
  } finally { bitmap.close() }
}
