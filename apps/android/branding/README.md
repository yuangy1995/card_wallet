# Android 卡包品牌资源

银行标识来源于 icongo/bank-logos（MIT）；卡组织标识来源于 aaronfagan/svg-credit-card-payment-icons（Apache-2.0）。固定版本、原始地址及 SHA-256 见 sources.json；原始 SVG 位于 sources/。转换为 192px 无损 WebP，保留原始颜色与比例，最终资源位于 drawable-nodpi。

完整许可证随应用打包在 assets/licenses。所有银行及卡组织商标仍归各自权利人；标识仅用于识别用户自行录入的卡片，不代表官方合作、授权或认证。未找到对应资产的银行使用名称缩写，不借用其他银行标识。

应用运行及常规 Gradle 构建均不下载标识，也不向第三方发送卡号、银行名称或用户卡片数据。卡组织识别只根据本地号码前缀提供显示提示，不是完整 BIN 验证；不能可靠识别时使用通用卡片图标。
