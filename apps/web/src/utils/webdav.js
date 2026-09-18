import { encryptSyncEnvelopeV4 } from './syncCryptoV4'
import { STORAGE_KEYS } from '@/config/constants'
import { localDataStore } from './indexedDbStorage'

const BACKUP_DIR = '/credit-card-backup'
const REQUEST_TIMEOUT = 60000
const aborted = () => new DOMException('同步已取消', 'AbortError')
export class WebDAVClient {
  constructor() {
    this.client = null
    this.config = null
    this.progressCallback = null
    this.controllers = new Set()
    this.requests = new Set()
    this.generation = 0
  }
  setProgressCallback(callback) { this.progressCallback = callback }
  disconnect() {
    this.generation++
    this.controllers.forEach(controller => controller.abort())
    this.requests.forEach(xhr => xhr.abort())
    this.controllers.clear()
    this.requests.clear()
    this.client = null
    this.config = null
    this.progressCallback = null
  }
  assertCurrent(generation) { if (generation !== this.generation || !this.client) throw aborted() }
  async request(operation) {
    const generation = this.generation
    this.assertCurrent(generation)
    const controller = new AbortController()
    this.controllers.add(controller)
    const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT)
    try {
      const result = await operation(this.client, controller.signal)
      this.assertCurrent(generation)
      return result
    } finally { clearTimeout(timeout); this.controllers.delete(controller) }
  }
  async initialize(config) {
    this.disconnect()
    const generation = this.generation
    const url = new URL(config.url)
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.hash || url.search) throw new Error('请填写不含账号、查询参数的 HTTP 或 HTTPS WebDAV 地址。')
    const { createClient } = await import('webdav')
    if (generation !== this.generation) throw aborted()
    this.client = createClient(url.href, { username: config.username, password: config.password })
    this.config = { ...config, url: url.href }
    try {
      if (!await this.request((client, signal) => client.exists(BACKUP_DIR, { signal }))) {
        await this.request((client, signal) => client.createDirectory(BACKUP_DIR, { signal }))
      }
      return true
    } catch (error) {
      if (generation === this.generation) this.disconnect()
      throw error
    }
  }
  async testConnection() {
    try { await this.request((client, signal) => client.getDirectoryContents('/', { signal })); return { success: true, message: '连接成功' } }
    catch (error) { return { success: false, message: error.message } }
  }
  async saveConfig(config) {
    if (!localDataStore.isUnlocked) throw new Error('请先解锁再保存同步设置。')
    await localDataStore.set(STORAGE_KEYS.WEBDAV_CONFIG, config)
    this.disconnect()
    return true
  }
  loadConfig() {
    if (!localDataStore.isUnlocked) return null
    return localDataStore.get(STORAGE_KEYS.WEBDAV_CONFIG, null)
  }
  async uploadSyncSnapshot(snapshot, password) {
    const generation = this.generation
    this.assertCurrent(generation)
    const syncPassword = String(password || '').trim()
    if (!syncPassword) throw new Error('请先设置同步密钥')
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const activeCount = snapshot.records.filter(record => record.state === 'active').length
    const filename = `${timestamp}---(${activeCount})[SyncV4][Web][自].json`
    const content = await encryptSyncEnvelopeV4(snapshot, syncPassword)
    this.assertCurrent(generation)
    const path = this.filePath(filename)
    if (typeof XMLHttpRequest !== 'undefined') await this.putTextWithProgress(path, content, (loaded, total) => this.progressCallback?.('upload', loaded, total))
    else await this.request((client, signal) => client.putFileContents(path, content, { signal, overwrite: true }))
    this.assertCurrent(generation)
    return filename
  }
  async getBackupList() {
    try {
      const files = await this.request((client, signal) => client.getDirectoryContents(BACKUP_DIR, { signal, deep: false, glob: '*.json' }))
      const data = files.filter(file => file.type !== 'directory').map(file => ({ filename: file.basename, basename: file.basename, lastmod: file.lastmod,
        lastModified: Date.parse(file.lastmod) || 0, size: file.size })).sort((a, b) => b.lastModified - a.lastModified)
      return { success: true, data }
    } catch (error) { return { success: false, message: error.message } }
  }
  filePath(filename) {
    if (!filename || /[\/\\]/.test(filename) || filename === '.' || filename === '..') throw new Error('备份文件名无效。')
    return `${BACKUP_DIR}/${filename}`
  }
  async restoreBackup(filename, onProgress = null) {
    try {
      const path = this.filePath(filename)
      const content = typeof XMLHttpRequest !== 'undefined'
        ? await this.getTextWithProgress(path, onProgress || ((loaded, total) => this.progressCallback?.('download', loaded, total)))
        : await this.request((client, signal) => client.getFileContents(path, { signal, format: 'text' }))
      try { return { success: true, data: JSON.parse(content) } }
      catch { return { success: true, data: content } }
    } catch (error) { return { success: false, message: error.message } }
  }
  async deleteBackup(filename) {
    try { await this.request((client, signal) => client.deleteFile(this.filePath(filename), { signal })); return { success: true } }
    catch (error) { return { success: false, message: error.message } }
  }
  buildAuthHeader() {
    if (!this.config) throw aborted()
    const bytes = new TextEncoder().encode(`${this.config.username}:${this.config.password}`)
    return 'Basic ' + btoa(Array.from(bytes, byte => String.fromCharCode(byte)).join(''))
  }
  backupFileUrl(path) {
    return String(this.config?.url || '').replace(/\/+$/, '') + path.split('/').map(encodeURIComponent).join('/')
  }
  transfer(method, path, content, progress) {
    const generation = this.generation
    this.assertCurrent(generation)
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest()
      this.requests.add(xhr)
      const finish = (error, result) => { this.requests.delete(xhr); error ? reject(error) : resolve(result) }
      xhr.open(method, this.backupFileUrl(path), true)
      xhr.timeout = REQUEST_TIMEOUT
      xhr.setRequestHeader('Authorization', this.buildAuthHeader())
      if (method === 'PUT') xhr.setRequestHeader('Content-Type', 'application/json; charset=utf-8')
      xhr.responseType = 'text'
      const target = method === 'PUT' ? xhr.upload : xhr
      target.onprogress = event => { if (generation === this.generation) progress?.(event.loaded, event.lengthComputable ? event.total : 0) }
      xhr.onerror = () => finish(new Error('连接失败，请检查网络、服务器证书与跨域设置。'))
      xhr.ontimeout = () => finish(new Error('连接超时，请稍后重试。'))
      xhr.onabort = () => finish(aborted())
      xhr.onload = () => {
        if (generation !== this.generation) { finish(aborted()); return }
        if (xhr.status < 200 || xhr.status >= 300) { finish(new Error(`服务器返回 ${xhr.status}`)); return }
        finish(null, xhr.responseText)
      }
      try { xhr.send(content) } catch (error) { finish(error) }
    })
  }
  getTextWithProgress(path, progress = null) { return this.transfer('GET', path, null, progress) }
  putTextWithProgress(path, content, progress = null) { return this.transfer('PUT', path, content, progress) }
}
export const webdavClient = new WebDAVClient()
