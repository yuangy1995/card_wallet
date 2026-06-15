import { createClient } from 'webdav';
import { encryptData, decryptData } from './encryption';
import { encryptSyncEnvelopeV4 } from './syncCryptoV4';

import { STORAGE_KEYS } from '@/config/constants'

export class WebDAVClient {
  constructor() {
    this.client = null;
    this.config = null;
    this.progressCallback = null;
  }

  // 设置进度回调
  setProgressCallback(callback) {
    this.progressCallback = callback;
  }

  // 初始化客户端
  async initialize(config) {
    try {
      const clientOptions = {
        username: config.username,
        password: config.password,
      };

      // 自定义请求处理
      clientOptions.fetcher = async (url, options) => {
        try {
          // 构建基本认证头
          const authHeader = 'Basic ' + btoa(`${config.username}:${config.password}`);
          
          // 合并请求头
          const headers = {
            ...options.headers,
            'Authorization': authHeader,
          };

          // 创建 AbortController 实例
          const controller = new AbortController();
          const signal = controller.signal;

          // 使用fetch API
          const response = await fetch(url, {
            ...options,
            headers,
            signal,
          });

          if (!response.ok) {
            throw new Error(`请求失败：${response.status} ${response.statusText}`);
          }

          // 如果是下载操作，处理进度
          if (options.method === 'GET' && this.progressCallback) {
            const reader = response.body.getReader();
            const contentLength = +response.headers.get('Content-Length') || 0;
            let receivedLength = 0;
            const progressCallback = this.progressCallback;

            const stream = new ReadableStream({
              start: async (controller) => {
                try {
                  while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    receivedLength += value.length;
                    controller.enqueue(value);
                    // 报告进度
                    if (contentLength > 0 && progressCallback) {
                      progressCallback('download', (receivedLength / contentLength) * 100);
                    }
                  }
                  controller.close();
                } catch (e) {
                  controller.error(e);
                }
              }
            });

            return new Response(stream, { headers: response.headers });
          }

          return response;
        } catch (error) {
          throw error;
        }
      };

      // 创建WebDAV客户端
      this.client = createClient(config.url, clientOptions);
      this.config = config;

      // 确保备份目录存在
      const backupDir = '/credit-card-backup';
      if (!await this.client.exists(backupDir)) {
        await this.client.createDirectory(backupDir);
      }

      return true;
    } catch (error) {
      throw new Error(`初始化失败：${error.message}`);
    }
  }

  // 测试连接
  async testConnection() {
    if (!this.client) {
      return {
        success: false,
        message: '请先配置 WebDAV 连接信息'
      };
    }

    try {
      // 尝试列出根目录内容来测试连接
      await this.client.getDirectoryContents('/');
      return {
        success: true,
        message: '连接成功'
      };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  // 保存配置
  saveConfig(config) {
    try {
      const encryptedConfig = encryptData(JSON.stringify(config));
      localStorage.setItem(STORAGE_KEYS.WEBDAV_CONFIG, encryptedConfig);
      this.config = config;
      this.client = null;
      return true;
    } catch (error) {
      throw new Error(`保存配置失败：${error.message}`);
    }
  }

  // 加载配置
  loadConfig() {
    try {
      const encryptedConfig = localStorage.getItem(STORAGE_KEYS.WEBDAV_CONFIG);
      if (!encryptedConfig) {
        return null;
      }
      const config = JSON.parse(decryptData(encryptedConfig));
      this.config = config;
      return config;
    } catch (error) {
      throw new Error(`加载配置失败：${error.message}`);
    }
  }

  async uploadSyncSnapshot(snapshot, syncPassword) {
    if (!this.client) {
      throw new Error('云同步服务还没有准备好');
    }
    const normalizedSyncPassword = String(syncPassword || '').trim();
    if (!normalizedSyncPassword) {
      throw new Error('请先设置同步密钥');
    }
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const activeCount = snapshot.records.filter(record => record.state === 'active').length;
    const filename = `${timestamp}---(${activeCount})[SyncV4][Web][自].json`;
    const encryptedSnapshot = await encryptSyncEnvelopeV4(snapshot, normalizedSyncPassword);
    if (typeof XMLHttpRequest !== 'undefined') {
      await this.putTextWithProgress(
        `/credit-card-backup/${filename}`,
        encryptedSnapshot,
        this.progressCallback
          ? (loaded, total) => this.progressCallback('upload', loaded, total)
          : null
      );
    } else {
      await this.client.putFileContents(`/credit-card-backup/${filename}`, encryptedSnapshot, {
        overwrite: true,
        contentLength: true
      });
      this.progressCallback?.('upload', encryptedSnapshot.length, encryptedSnapshot.length);
    }
    return filename;
  }

  // 获取备份列表
  async getBackupList() {
    if (!this.client) {
      return {
        success: false,
        message: '云同步服务还没有准备好'
      };
    }

    try {
      // 检查并创建备份目录
      const backupDir = '/credit-card-backup';
      if (!await this.client.exists(backupDir)) {
        await this.client.createDirectory(backupDir);
      }

      const files = await this.client.getDirectoryContents('/credit-card-backup', {
        deep: false,
        glob: '*.json'
      });

      // 先处理文件名，再排序
      const processedFiles = files.map(file => ({
        filename: file.basename,
        basename: file.basename,
        lastmod: file.lastmod,
        lastModified: file.lastmod ? new Date(file.lastmod).getTime() : 0,
        size: file.size
      }));

      // 按时间倒序排序
      processedFiles.sort((a, b) => new Date(b.lastmod) - new Date(a.lastmod));

      return {
        success: true,
        data: processedFiles
      };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  // 恢复备份
  async restoreBackup(filename, onProgress = null) {
    if (!this.client) {
      throw new Error('云同步服务还没有准备好');
    }

    try {
      const filepath = `/credit-card-backup/${filename}`;
      
      const progressHandler = onProgress || (
        this.progressCallback
          ? (loaded, total) => this.progressCallback('download', loaded, total)
          : null
      );
      const content = typeof XMLHttpRequest !== 'undefined'
        ? await this.getTextWithProgress(filepath, progressHandler)
        : await this.client.getFileContents(filepath, { format: 'text' });

      // 尝试解析 JSON
      try {
        const jsonData = JSON.parse(content);
        return {
          success: true,
          data: jsonData
        };
      } catch (error) {
        // 如果解析失败，可能是加密数据，直接返回
        return {
          success: true,
          data: content
        };
      }
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  // 删除备份
  async deleteBackup(filename) {
    if (!this.client) {
      throw new Error('云同步服务还没有准备好');
    }

    try {
      const filepath = `/credit-card-backup/${filename}`;
      await this.client.deleteFile(filepath);
      return {
        success: true,
        message: '删除成功'
      };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  buildAuthHeader() {
    if (!this.config) return '';
    return 'Basic ' + btoa(`${this.config.username}:${this.config.password}`);
  }

  backupFileUrl(filepath) {
    const baseUrl = String(this.config?.url || '').replace(/\/+$/, '');
    const normalizedPath = String(filepath || '').startsWith('/') ? filepath : `/${filepath}`;
    return `${baseUrl}${normalizedPath.split('/').map((segment) => encodeURIComponent(segment)).join('/')}`;
  }

  getTextWithProgress(filepath, onProgress = null) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('GET', this.backupFileUrl(filepath), true);
      xhr.setRequestHeader('Authorization', this.buildAuthHeader());
      xhr.responseType = 'text';
      onProgress?.(0, 0);
      xhr.onprogress = (event) => {
        onProgress?.(event.loaded || 0, event.lengthComputable ? event.total : 0);
      };
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          onProgress?.(xhr.responseText?.length || 0, xhr.responseText?.length || 0);
          resolve(xhr.responseText || '');
        } else {
          reject(new Error(`下载失败：HTTP ${xhr.status}`));
        }
      };
      xhr.onerror = () => reject(new Error('下载失败：网络连接中断'));
      xhr.send();
    });
  }

  putTextWithProgress(filepath, content, onProgress = null) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('PUT', this.backupFileUrl(filepath), true);
      xhr.setRequestHeader('Authorization', this.buildAuthHeader());
      xhr.setRequestHeader('Content-Type', 'text/plain; charset=utf-8');
      const totalBytes = new TextEncoder().encode(content).length;
      onProgress?.(0, totalBytes);
      xhr.upload.onprogress = (event) => {
        onProgress?.(event.loaded || 0, event.lengthComputable ? event.total : totalBytes);
      };
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          onProgress?.(totalBytes, totalBytes);
          resolve();
        } else {
          reject(new Error(`上传失败：HTTP ${xhr.status}`));
        }
      };
      xhr.onerror = () => reject(new Error('上传失败：网络连接中断'));
      xhr.send(content);
    });
  }

}

// 导出单例实例
export const webdavClient = new WebDAVClient();
