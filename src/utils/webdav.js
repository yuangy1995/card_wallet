import { createClient } from 'webdav';
import { encryptData, decryptData } from './encryption';

const WEBDAV_CONFIG_KEY = 'webdav_config';

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

            const stream = new ReadableStream({
              async start(controller) {
                while (true) {
                  const { done, value } = await reader.read();
                  if (done) break;
                  receivedLength += value.length;
                  controller.enqueue(value);
                  // 报告进度
                  if (contentLength > 0) {
                    this.progressCallback('download', receivedLength / contentLength * 100);
                  }
                }
                controller.close();
              }
            });

            return new Response(stream, { headers: response.headers });
          }

          // 如果是上传操作，处理进度
          if (options.method === 'PUT' && this.progressCallback && options.body) {
            const totalSize = options.body.length;
            let uploadedSize = 0;
            const stream = new ReadableStream({
              start: async (controller) => {
                const reader = options.body.getReader();
                while (true) {
                  const { done, value } = await reader.read();
                  if (done) break;
                  uploadedSize += value.length;
                  controller.enqueue(value);
                  // 报告进度
                  this.progressCallback('upload', uploadedSize / totalSize * 100);
                }
                controller.close();
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
        console.log('已创建备份目录:', backupDir);
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
      localStorage.setItem(WEBDAV_CONFIG_KEY, encryptedConfig);
      this.config = config;
      return true;
    } catch (error) {
      throw new Error(`保存配置失败：${error.message}`);
    }
  }

  // 加载配置
  loadConfig() {
    try {
      const encryptedConfig = localStorage.getItem(WEBDAV_CONFIG_KEY);
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

  // 创建备份
  async createBackup(data) {
    if (!this.client) {
      throw new Error('WebDAV 客户端未初始化');
    }

    try {
      // 创建备份目录
      const backupDir = '/credit-card-backup';
      if (!await this.client.exists(backupDir)) {
        await this.client.createDirectory(backupDir);
      }

      // 创建备份文件名
      const now = new Date();
      const timestamp = now.toLocaleString('zh-CN', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: false
      }).replace(/[\/:]/g, '-').replace(', ', '_');
      
      const filename = `backup-${timestamp}.json`;
      const filepath = `${backupDir}/${filename}`;

      // 报告开始上传
      if (this.progressCallback) {
        this.progressCallback('upload', 0);
      }

      // 上传备份数据
      const jsonData = JSON.stringify(data);
      await this.client.putFileContents(filepath, jsonData, {
        overwrite: true,
        contentLength: true
      });

      // 报告上传完成
      if (this.progressCallback) {
        this.progressCallback('upload', 100);
      }

      return {
        success: true,
        message: '备份成功',
        filename: filename
      };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  // 获取备份列表
  async getBackupList() {
    if (!this.client) {
      return {
        success: false,
        message: 'WebDAV 客户端未初始化'
      };
    }

    try {
      // 检查并创建备份目录
      const backupDir = '/credit-card-backup';
      if (!await this.client.exists(backupDir)) {
        await this.client.createDirectory(backupDir);
        console.log('已创建备份目录:', backupDir);
      }

      const files = await this.client.getDirectoryContents('/credit-card-backup', {
        deep: false,
        glob: '*.json'
      });

      return {
        success: true,
        data: files.map(file => ({
          filename: file.basename,
          basename: file.basename,
          lastmod: file.lastmod,
          size: file.size
        }))
      };
    } catch (error) {
      return { success: false, message: error.message };
    }
  }

  // 恢复备份
  async restoreBackup(filename) {
    if (!this.client) {
      throw new Error('WebDAV 客户端未初始化');
    }

    try {
      const filepath = `/credit-card-backup/${filename}`;
      
      // 报告开始下载
      if (this.progressCallback) {
        this.progressCallback('download', 0);
      }

      // 下载备份文件
      const content = await this.client.getFileContents(filepath, {
        format: 'text'
      });

      // 报告下载完成
      if (this.progressCallback) {
        this.progressCallback('download', 100);
      }

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
      throw new Error('WebDAV 客户端未初始化');
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
}

// 导出单例实例
export const webdavClient = new WebDAVClient();
