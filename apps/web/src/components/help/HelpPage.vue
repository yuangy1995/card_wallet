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
        <h2>卡包使用指南</h2>
        
        <el-divider content-position="left">快速开始</el-divider>
        <div class="section">
          <h3>基础操作</h3>
          <ol>
            <li>
              <strong>添加新卡：</strong>
              <p>点击右上角的“新增卡片”，填写国家/地区、银行、卡号、有效期、币种、权益、备注和卡片图片等信息。</p>
              <ul>
                <li>卡号和 CVV 支持掩码显示，点击眼睛图标可临时查看。</li>
                <li>有效期使用 MM/YY 格式保存。</li>
                <li>信用卡支持同银行共享额度、账单日、还款日、年费和免息期计算。</li>
                <li>储蓄卡不参与信用额度、年费和免息期统计。</li>
              </ul>
            </li>
            <li>
              <strong>查看和切换视图：</strong>
              <p>控制中心左侧可在“表格”和“卡片”视图之间切换。</p>
              <ul>
                <li>表格视图适合快速查看、勾选、右键编辑、删除和查看详情。</li>
                <li>卡片视图支持按发卡行、地区、卡组织分组，支持额度、年费时间、最近修改时间排序。</li>
                <li>切换视图会自动清除当前批量勾选，避免跨视图误操作。</li>
              </ul>
            </li>
          </ol>
        </div>

        <el-divider content-position="left">核心功能</el-divider>
        <div class="section">
          <h3>搜索和筛选</h3>
          <ul>
            <li>顶部“任意内容检索”会搜索卡类别、别名、银行、卡号、等级、币种、国家、权益、备注和额度。</li>
            <li>点击“展开筛选”可使用高级筛选，按卡类别、国家、银行、卡号、等级、额度、年费状态、权益和备注过滤。</li>
            <li>任意内容检索和高级筛选互斥：输入其中一种条件时，系统会自动清空另一种条件。</li>
            <li>“重置”会清空筛选条件并恢复全部卡片列表。</li>
          </ul>

          <h3>数据安全</h3>
          <ul>
            <li>可在“更多 -> 安全设置”中设置或修改应用密码。</li>
            <li>右上角锁定按钮可手动锁定应用；锁定时会关闭已打开的业务弹窗。</li>
            <li>卡号和 CVV 默认掩码显示，云同步文件使用同步密钥加密。</li>
            <li>忘记密码时，可通过已保存卡片信息进行恢复；也可以选择清除全部本地数据后重新设置。</li>
          </ul>

          <h3>数据管理</h3>
          <ul>
            <li><strong>加密云同步：</strong>
              <p>“云同步设置”使用 WebDAV 存储加密同步文件，不再使用旧版手动导入、导出和备份入口。</p>
              <ul>
                <li>“更多 -> 云同步设置”配置协议、地址、端口、路径、账号、密码和同步密钥，保存后会重新启动云同步状态检测。</li>
                <li>顶部状态胶囊展示同步状态、最近更新时间和下次自动同步倒计时。</li>
                <li>云端没有新版同步文件时，点击“立即同步”会用当前 Web 本地数据初始化云同步。</li>
                <li>后续同步只读取新版自动同步文件，旧版文件不会参与合并。</li>
              </ul>
            </li>
          </ul>
        </div>

        <el-divider content-position="left">高级功能</el-divider>
        <div class="section">
          <h3>年费管理</h3>
          <ul>
            <li>“年费提醒”只检查信用卡中未达标、60 天内即将收取、以及已过期 60 天内的年费卡片。</li>
            <li>应用启动时也会执行年费检查；如果应用处于锁定状态，检查会延后到解锁后执行。</li>
            <li>表格右键可将未达标卡片设置为已达标；卡片视图右键或卡片背面标签也可快捷标记。</li>
            <li>标记为已达标时，下次年费收取时间会自动顺延一年。</li>
            <li>批量操作中可统一更新年费金额、年费状态和下次年费收取时间；选择“终免年费”会清空下次年费时间。</li>
          </ul>

          <h3>批量操作</h3>
          <ul>
            <li>在表格视图勾选行，或在卡片视图勾选卡片后，会显示批量操作工具栏。</li>
            <li>支持批量删除、标记达标、标记未达标、批量更新年费、批量更新有效期和批量修改卡类别。</li>
            <li>批量更新会刷新卡片的最后修改时间，并通过统一同步流程保存。</li>
          </ul>

          <h3>免息期计算</h3>
          <ul>
            <li>信用卡需要设置账单日和还款日后才会显示免息期。</li>
            <li>系统会根据当前日期、账单日、还款日和“账单日消费计入”设置自动计算。</li>
          </ul>

          <h3>统计分析</h3>
          <ul>
            <li>“统计分析”可查看信用卡总额度、共享额度、独立额度、年费状态，以及储蓄卡的国家/地区、银行和币种分布。</li>
            <li>统计页支持导出统计数据。</li>
          </ul>

          <h3>个性化设置</h3>
          <ul>
            <li>“更多 -> 自定义列”可选择表格中显示的信息，支持全选、取消全选和恢复默认。</li>
            <li>右上角主题按钮可切换浅色极光模式和深色太空模式。</li>
          </ul>
        </div>

        <el-divider content-position="left">使用技巧</el-divider>
        <div class="section">
          <h3>快捷操作</h3>
          <ul>
            <li><strong>键盘快捷键：</strong>
              <p>系统支持以下全局快捷键：</p>
              <ul>
                <li><kbd>Ctrl+N</kbd> - 新增卡片</li>
                <li><kbd>Ctrl+H</kbd> 或 <kbd>F1</kbd> - 使用帮助</li>
                <li><kbd>Ctrl+T</kbd> - 自定义列</li>
                <li><kbd>Ctrl+S</kbd> - 统计分析</li>
                <li><kbd>Ctrl+Shift+W</kbd> - 云同步设置</li>
                <li><kbd>Ctrl+Shift+C</kbd> - 清除所有数据</li>
                <li><kbd>Escape</kbd> - 关闭当前主要弹窗</li>
              </ul>
              <p><em>注意：焦点在输入框或文本域中时，除 Escape 外不会触发全局快捷键，避免干扰正常录入。</em></p>
            </li>
            <li><strong>表格右键菜单：</strong>
              <p>在表格行上右键点击可快速：</p>
              <ul>
                <li>确认本周期年费已达标</li>
                <li>编辑卡片信息</li>
                <li>删除卡片</li>
                <li>查看详情</li>
              </ul>
            </li>
            <li><strong>卡片右键菜单：</strong>
              <p>在卡片视图中右键点击卡片可快速翻转、编辑、删除、查看详情和标记年费已达标。</p>
            </li>
            <li><strong>同步建议：</strong>
              <ul>
                <li>升级前，先确认三端都已经同步到最新数据。</li>
                <li>首次初始化新版云同步时，使用数据最新的一端点击“立即同步”。</li>
                <li>妥善保存同步密钥，三端必须使用同一个密钥才能解密同步文件。</li>
              </ul>
            </li>
          </ul>

          <h3>移动端优化</h3>
          <ul>
            <li>小屏幕下“统计分析”“年费提醒”等常用入口会收纳到“更多”菜单中。</li>
            <li>表格会隐藏部分不常用信息，弹窗会适配移动端宽度。</li>
            <li>按钮和选择控件已增大触摸区域，适合手机和平板使用。</li>
          </ul>

          <h3>性能与稳定性</h3>
          <ul>
            <li>搜索输入使用 300 毫秒防抖，减少频繁计算。</li>
            <li>弹窗和卡片视图按需加载，降低初始加载成本。</li>
            <li>数据加载、保存、删除、同步等关键操作会显示状态提示。</li>
          </ul>
        </div>

        <el-divider content-position="left">WebDAV 配置</el-divider>
        <div class="section">
          <h3>WebDAV 同步</h3>
          <p>系统支持通过 WebDAV 做加密云同步。配置完成后，可通过顶部“立即同步”发布或更新当前云同步文件。</p>
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
import { ref, watch, inject } from 'vue'
import { useAutoLock } from '@/composables/useAutoLock'

const visible = ref(false)
const providedAutoLock = inject('autoLock', null)
const { isLocked } = providedAutoLock || useAutoLock()

// 监听对话框显示状态，当显示时禁用body滚动
watch(visible, (val) => {
  if (val) {
    document.body.style.overflow = 'hidden'
  } else {
    document.body.style.overflow = ''
  }
})

watch(isLocked, (locked) => {
  if (locked && visible.value) {
    visible.value = false
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
<h1>卡包 WebDAV 版本完整配置</h1>

<p>一个安全的部署方案是应用使用 HTTPS，并且 WebDAV 服务/服务商也使用 HTTPS。</p>

<h2>部署卡包</h2>

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

const hideHelp = () => {
  visible.value = false
}

defineExpose({
  showHelp,
  hideHelp
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
