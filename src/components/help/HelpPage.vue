<template>
  <el-dialog
    v-model="visible"
    width="60%"
    class="help-dialog"
    draggable
    top="5vh"
    :close-on-click-modal="false"
    :close-on-press-escape="true"
    :show-close="false"
    :modal-class="'help-dialog-modal'"
  >
    <el-scrollbar height="75vh" class="help-scrollbar">
      <div class="help-content">
        <h2>信用卡管理系统使用指南</h2>
        
        <el-divider content-position="left">快速开始</el-divider>
        <div class="section">
          <h3>🚀 基础操作</h3>
          <ol>
            <li>
              <strong>添加新卡：</strong>
              <p>点击顶部的"新增信用卡"按钮，填写信用卡信息，包括：</p>
              <ul>
                <li>卡片名称（如：xx银行信用卡）</li>
                <li>卡号（支持加密显示）</li>
                <li>CVV码（支持加密显示）</li>
                <li>有效期</li>
                <li>额度和其他信息</li>
              </ul>
            </li>
            <li>
              <strong>查看卡片：</strong>
              <p>所有信用卡信息将在主表格中显示，支持：</p>
              <ul>
                <li>点击表头排序</li>
                <li>使用搜索栏筛选</li>
                <li>自定义显示列</li>
              </ul>
            </li>
          </ol>
        </div>

        <el-divider content-position="left">核心功能</el-divider>
        <div class="section">
          <h3>🔍 搜索和筛选</h3>
          <ul>
            <li>支持多条件组合搜索</li>
            <li>可按卡片状态、银行、额度等进行筛选</li>
            <li>支持模糊搜索和精确匹配</li>
          </ul>

          <h3>🔒 数据安全</h3>
          <ul>
            <li>敏感信息（卡号、CVV）默认加密显示</li>
            <li>点击眼睛图标可临时查看完整信息</li>
            <li>所有数据使用AES加密存储</li>
          </ul>

          <h3>📊 数据管理</h3>
          <ul>
            <li><strong>导出数据：</strong>
              <p>点击"导出数据"按钮，系统会将所有信用卡信息导出为加密文件：</p>
              <ul>
                <li>可设置自定义密码保护</li>
                <li>导出为加密格式，方便安全的备份和迁移</li>
              </ul>
            </li>
            <li><strong>导入数据：</strong>
              <p>点击"导入数据"按钮，可导入之前导出的数据文件：</p>
              <ul>
                <li>需要输入导出时设置的密码</li>
              </ul>
            </li>
            <li><strong>WebDAV 云端备份：</strong>
              <p>支持通过 WebDAV 服务器进行云端备份和恢复：</p>
              <ul>
                <li>配置 WebDAV 服务器：
                  <ul>
                    <li>支持 HTTP/HTTPS 协议</li>
                    <li>可配置服务器地址、端口和路径</li>
                    <li>支持用户名密码认证</li>
                    <li>HTTPS 可选择是否验证证书</li>
                  </ul>
                </li>
                <li>创建备份：
                  <ul>
                    <li>支持自定义备份密码</li>
                    <li>显示备份进度</li>
                    <li>自动加密保护数据</li>
                  </ul>
                </li>
                <li>恢复备份：
                  <ul>
                    <li>显示所有可用的备份列表</li>
                    <li>显示备份时间和大小</li>
                    <li>需要输入备份密码才能恢复</li>
                  </ul>
                </li>
                <li>备份管理：
                  <ul>
                    <li>支持删除历史备份</li>
                    <li>显示备份状态和详细信息</li>
                  </ul>
                </li>
              </ul>
            </li>
            <li><strong>本地备份：</strong>
              <p>系统提供完善的本地备份功能：</p>
              <ul>
                <li>自动备份：
                  <ul>
                    <li>每次修改数据后1分钟自动创建备份</li>
                    <li>保留最近50条备份记录</li>
                  </ul>
                </li>
                <li>手动备份：
                  <ul>
                    <li>点击"本地备份"按钮查看备份历史</li>
                    <li>显示备份时间和信用卡数量</li>
                  </ul>
                </li>
                <li>备份管理：
                  <ul>
                    <li>预览：查看备份内容，显示与当前数据的差异</li>
                    <li>恢复：可随时恢复到任意备份版本</li>
                    <li>自动清理：超出50条的旧备份将被自动删除</li>
                  </ul>
                </li>
              </ul>
            </li>
          </ul>
        </div>

        <el-divider content-position="left">高级功能</el-divider>
        <div class="section">
          <h3>⏰ 年费管理</h3>
          <ul>
            <li>可手动标记年费达标状态</li>
            <li>显示距离上次提额天数</li>
            <li><strong>年费达标检测：</strong>
              <p>系统会在以下情况自动检测年费达标状态：</p>
              <ul>
                <li>每次打开应用时</li>
                <li>点击"检测年费情况"按钮时</li>
              </ul>
              <p>检测内容包括：</p>
              <ul>
                <li>临近年费收取时间的卡片（60天内）</li>
                <li>已过期的年费</li>
                <li>未达标的卡片</li>
              </ul>
            </li>
            <li><strong>年费达标状态智能提醒：</strong>
              <p>当检测到卡片临近年费收取时间（60天内）时：</p>
              <ul>
                <li>系统会弹出提示框，列出所有需要关注的卡片</li>
                <li>可以选择一键将这些卡片更新为未达标状态</li>
                <li>帮助您避免遗漏年费收取情况</li>
              </ul>
            </li>
            <li><strong>年费达标状态管理：</strong>
              <p>可以通过以下方式管理年费达标状态：</p>
              <ul>
                <li>在表格中右键点击卡片，选择"设置年费已达标"</li>
                <li>在编辑卡片信息时修改年费达标状态</li>
                <li>使用智能提醒功能批量更新状态</li>
              </ul>
            </li>
            <li><strong>年费状态显示：</strong>
              <p>系统使用不同的标签颜色来区分年费状态：</p>
              <ul>
                <li>绿色：已达标</li>
                <li>红色：未达标</li>
                <li>灰色：终免年费</li>
              </ul>
            </li>
          </ul>

          <h3>⌛ 免息期计算</h3>
          <ul>
            <li><strong>自动计算：</strong>
              <p>系统会根据每张卡的账单日和还款日自动计算免息期：</p>
              <ul>
                <li>需要设置账单日和还款日才能计算</li>
                <li>免息期 = 还款日期 - 当前日期</li>
                <li>每天实时更新免息期天数</li>
              </ul>
            </li>
          </ul>

          <h3>📈 数据分析</h3>
          <ul>
            <li>查看信用卡使用统计</li>
            <li>额度分布分析</li>
            <li>银行占比统计</li>
          </ul>

          <h3>⚙️ 个性化设置</h3>
          <ul>
            <li><strong>表格定制：</strong>
              <p>点击"自定义列"按钮可以：</p>
              <ul>
                <li>选择要显示的列</li>
              </ul>
            </li>
          </ul>
        </div>

        <el-divider content-position="left">使用技巧</el-divider>
        <div class="section">
          <h3>💡 快捷操作</h3>
          <ul>
            <li><strong>表格右键菜单：</strong>
              <p>在表格行上右键点击可快速：</p>
              <ul>
                <li>编辑卡片信息</li>
                <li>删除卡片</li>
                <li>查看详情</li>
              </ul>
            </li>
            <li><strong>数据备份建议：</strong>
              <ul>
                <li>定期导出数据保存</li>
                <li>更新重要信息后及时备份</li>
                <li>妥善保管导出文件的密码</li>
              </ul>
            </li>
          </ul>
        </div>

        <el-divider content-position="left">WebDAV 配置</el-divider>
        <div class="section">
          <h3>🔐 WebDAV 同步</h3>
          <p>本系统支持通过 WebDAV 进行数据同步和备份。</p>
          <div class="webdav-section">
            <el-button type="primary" @click="openWebDAVDocs">
              查看 WebDAV 完整配置说明
            </el-button>
          </div>
        </div>
      </div>
    </el-scrollbar>
    <template #footer>
      <span class="dialog-footer">
        <el-button @click="visible = false">关闭</el-button>
      </span>
    </template>
  </el-dialog>
</template>

<script setup>
import { ref, watch } from 'vue'

const visible = ref(false)

// 监听对话框显示状态，当显示时禁用body滚动
watch(visible, (val) => {
  if (val) {
    document.body.style.overflow = 'hidden'
  } else {
    document.body.style.overflow = ''
  }
})

const openWebDAVDocs = () => {
  // 将内容保存到单独的文件中以保持代码整洁
  const webdavContent = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WebDAV 配置说明</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 900px;
            margin: 0 auto;
            padding: 20px;
        }
        pre {
            background-color: #f6f8fa;
            border-radius: 6px;
            padding: 16px;
            overflow: auto;
        }
        code {
            font-family: SFMono-Regular, Consolas, 'Liberation Mono', Menlo, monospace;
            font-size: 14px;
        }
        :is(h1), :is(h2), :is(h3) {
            border-bottom: 1px solid #eaecef;
            padding-bottom: .3em;
        }
    </style>
</head>
<body>
<h1>信用卡管理 WebDAV 版本完整配置</h1>

<p>一个安全的部署方案是应用使用 HTTPS，并且 WebDAV 服务/服务商也使用 HTTPS。</p>

<h2>部署信用卡管理</h2>

<p>nginx 加入以下区块：</p>

<pre><code>location /card {
    alias /usr/share/nginx/html_admin/card;  # 替换为你的实际打包后的dist目录路径
    try_files $uri $uri/ /card/index.html;  # 支持 Vue 路由的 history 模式
    index index.html;
}</code></pre>

<p>此时，可以使用浏览器 https://yourdomain.com/card 访问应用了。</p>

<h2>使用服务商托管的 WebDAV</h2>

<p>登录你的 WebDAV 配置页面：</p>
<ul>
    <li>开启 HTTPS</li>
    <li>将托管的域名填入 CORS 允许跨源里，比如 https://yourdomain.com</li>
</ul>

<h2>使用自托管的 WebDAV</h2>

<h3>nginx 配置</h3>

<p>同源配置：</p>

<pre><code>location /webdav {
    proxy_pass http://127.0.0.1:8082;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header REMOTE-HOST $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $host;
    proxy_redirect off;
}</code></pre>

<p>不同源配置：</p>

<pre><code>location ^~ /webdav/ {
    if ($request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Origin' $http_origin always;
        add_header 'Access-Control-Allow-Methods' 'PROPFIND,OPTIONS,GET,POST,PUT,DELETE,MKCOL,COPY,MOVE' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization,Depth,Content-Type' always;
        add_header 'Access-Control-Allow-Credentials' 'true' always;
        add_header 'Access-Control-Max-Age' '3600' always;
        return 204;
    }

    # 非 OPTIONS 请求的 CORS 头
    add_header 'Access-Control-Allow-Origin' $http_origin always;
    add_header 'Access-Control-Allow-Credentials' 'true' always;

    proxy_pass http://127.0.0.1:8082;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header REMOTE-HOST $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $host;
    proxy_redirect off;
}</code></pre>

<h3>WebDAV 服务</h3>

<p>使用这个服务：<a href="https://github.com/hacdias/webdav" target="_blank">https://github.com/hacdias/webdav</a></p>

<p>启动命令：webdav -c config.yaml</p>

<p>yaml 内容参考：</p>

<pre><code>address: 127.0.0.1
port: 8082

prefix: /webdav

debug: false
noSniff: false
behindProxy: true

directory: /data/webdav/data

permissions: CRUD

rules: []

log:
  format: console
  colors: true
  outputs:
  - stderr

cors:
  enabled: true
  credentials: true
  allowed_headers:
    - Depth
  allowed_hosts:
    - http://localhost:8080
    - http://yovey.lov.us
    - https://yovey.lov.us
    - https://sgp.lov.us
  allowed_methods:
    - GET
  exposed_headers:
    - Content-Length
    - Content-Range

users:
  - username: 'card'
    password: 'card1111111111111111111111111'
    directory: '/data/webdav/data/king_directory'
  - username: 'admin'
    password: 'lil2222222222222222222222222'
    directory: '/data/webdav/data/admin_directory'
  - username: 'test_user'
    password: 'test_user20241204'
    directory: '/data/webdav/data/test_user20241204'
  - username: johnqqqqqqqqqqqqqqqqqqqqqq
    password: "{bcrypt}$2y$10$zEP6oofmXFeHaeMfBNLnP.DO8m.H.Mwhd24/TOX2MWLxAExXi4qgi"
    directory: /another/path
  - username: basicqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq
    password: basic
    permissions: CRUD
    rules:
      - path: /some/file
        permissions: none
      - path: /tmp/admin
        permissions: CRUD
      - regex: "^.+.js$"
        permissions: RU</code></pre>

<h3>配置说明：</h3>
<ul>
    <li>端口：需要与 nginx 指向的端口保持一致</li>
    <li>prefix：需要与 nginx 配置的 location 保持一致</li>
    <li>directory 和 user 下的 location：分别是默认路径和用户指定的路径，都需要确保存在，否则会返回 404</li>
    <li>allowed_hosts：允许的跨源来源域名，需要添加部署应用的域名</li>
</ul>
</body>
</html>`

  // 创建一个blob对象，指定 HTML 类型和 UTF-8 编码
  const blob = new Blob([webdavContent], { type: 'text/html;charset=utf-8' })
  const url = window.URL.createObjectURL(blob)
  
  // 在新窗口中打开
  window.open(url, '_blank')
  
  // 清理URL对象
  setTimeout(() => {
    window.URL.revokeObjectURL(url)
  }, 100)
}

const showHelp = () => {
  visible.value = true
}

defineExpose({
  showHelp
})
</script>

<style lang="scss" scoped>
.help-dialog {
  :deep(.el-dialog) {
    margin: 0;
    position: relative;
    margin: 15vh auto 50px;
    display: flex;
    flex-direction: column;
    max-height: 85vh;
    
    .el-dialog__header {
      cursor: move;
      background: var(--el-color-primary-light-8);
      margin: 0;
      padding: 15px 20px;
      border-bottom: 1px solid var(--el-border-color-lighter);
      flex-shrink: 0;
    }

    .el-dialog__body {
      padding: 0;
      flex: 1;
      overflow: hidden;
    }

    .el-dialog__footer {
      border-top: 1px solid var(--el-border-color-lighter);
      padding: 15px 20px;
      flex-shrink: 0;
    }
  }
}

.help-scrollbar {
  overflow: hidden;
  
  :deep(.el-scrollbar__wrap) {
    overflow-x: hidden;
  }
}

.help-content {
  padding: 20px;
  
  h2 {
    text-align: center;
    color: var(--el-color-primary);
    margin-bottom: 20px;
  }

  .section {
    margin-bottom: 20px;

    :is(h3) {
      color: var(--el-color-primary);
      margin: 15px 0;
    }

    ul, ol {
      padding-left: 20px;
      margin: 10px 0;

      li {
        margin: 8px 0;
        line-height: 1.5;

        strong {
          color: var(--el-color-primary);
        }

        p {
          margin: 5px 0;
        }

        ul {
          margin: 5px 0;
        }
      }
    }
  }

  .el-divider__text {
    font-size: 18px;
    font-weight: bold;
    color: var(--el-color-primary);
  }
}
</style>

<style>
.help-dialog-modal {
  overflow: hidden;
}
</style>
