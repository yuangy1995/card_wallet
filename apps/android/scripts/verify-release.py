"""验证正式 APK，签名指纹来自已发布的 Android 1.2.0（4）。"""
import re
import subprocess
import sys
from pathlib import Path


RELEASE_CERTIFICATE = "e09a2af6d581dd247df0d4ae3ba08b957fee69cfbdd1b0b89dc37c958559a1cf"


def validate_metadata(badging, certificates, version, build):
    package = re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging, re.M)
    if not package or package.groups() != ("com.applist.cardwallet", build, version):
        raise ValueError("APK 应用标识或版本与发布配置不一致")
    if not re.search(r"^minSdkVersion:'23'$", badging, re.M):
        raise ValueError("APK 最低系统版本不符合当前稳定通道")
    if re.search(r"^application-debuggable", badging, re.M):
        raise ValueError("不能发布调试 APK")
    fingerprints = re.findall(r"^Signer #\d+ certificate SHA-256 digest: ([0-9a-f]+)$", certificates, re.M)
    if fingerprints != [RELEASE_CERTIFICATE]:
        raise ValueError("APK 签名与现有正式版不一致，不能覆盖升级")
    for scheme in ["v1 scheme (JAR signing)", "v2 scheme (APK Signature Scheme v2)"]:
        if f"Verified using {scheme}: true" not in certificates:
            raise ValueError("APK 缺少兼容现有设备的 v1/v2 签名")


def verify(apk, version, build, build_tools):
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version) or not re.fullmatch(r"[1-9][0-9]*", build):
        raise ValueError("发布版本格式不正确")
    if apk.name != f"CardWallet-Android-{build}.apk":
        raise ValueError("APK 文件名不符合更新通道约定")
    badging = subprocess.run([str(build_tools / "aapt2"), "dump", "badging", str(apk)],
                             check=True, capture_output=True, text=True).stdout
    certificates = subprocess.run([str(build_tools / "apksigner"), "verify", "--verbose", "--print-certs", str(apk)],
                                  check=True, capture_output=True, text=True).stdout
    validate_metadata(badging, certificates, version, build)


if __name__ == "__main__":
    try:
        if len(sys.argv) != 5:
            raise ValueError("用法：verify-release.py <APK> <版本> <版本编号> <Android build-tools 目录>")
        verify(Path(sys.argv[1]), sys.argv[2], sys.argv[3], Path(sys.argv[4]))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        # 不输出构建工具的原始输入或凭据。
        print(f"Android 发布校验失败：{error}", file=sys.stderr)
        sys.exit(1)
    print("APK 应用标识、版本、最低系统版本及正式签名验证通过。")
