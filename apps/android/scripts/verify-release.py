"""验证正式 APK；可信证书指纹由发布环境提供，不再信任已泄漏的旧签名。"""
import os
import re
import subprocess
import sys
from pathlib import Path


# 公开证书指纹，不是私钥；保留为拒绝列表，避免误把泄漏密钥重新放入 Secrets。
COMPROMISED_CERTIFICATE = "e09a2af6d581dd247df0d4ae3ba08b957fee69cfbdd1b0b89dc37c958559a1cf"


def expected_certificate(value=None):
    from_environment = value is None
    value = os.environ.get("ANDROID_SIGNING_CERT_SHA256", "") if from_environment else value
    fingerprint = value.strip().replace(":", "").lower()
    if not re.fullmatch(r"[0-9a-f]{64}", fingerprint):
        raise ValueError("必须配置有效的 ANDROID_SIGNING_CERT_SHA256，不能从待校验 APK 自动生成信任基准")
    if fingerprint == COMPROMISED_CERTIFICATE:
        raise ValueError("旧发布签名已经泄漏，必须生成新密钥，不能继续使用旧证书")
    if from_environment:
        pinned = Path(__file__).resolve().parents[1].joinpath("signing-certificate.sha256").read_text().strip()
        if fingerprint != pinned:
            raise ValueError("CI 证书指纹与源码中的新发布证书不一致")
    return fingerprint


def validate_metadata(badging, certificates, version, build, certificate=None):
    trusted = expected_certificate(certificate)
    package = re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging, re.M)
    if not package or package.groups() != ("com.applist.cardwallet", build, version):
        raise ValueError("APK 应用标识或版本与发布配置不一致")
    if not re.search(r"^minSdkVersion:'23'$", badging, re.M):
        raise ValueError("APK 最低系统版本不符合当前稳定通道")
    if re.search(r"^application-debuggable", badging, re.M):
        raise ValueError("不能发布调试 APK")
    fingerprints = re.findall(r"^Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]+)$", certificates, re.M)
    if [fingerprint.lower() for fingerprint in fingerprints] != [trusted]:
        raise ValueError("APK 签名与发布环境中配置的新证书不一致")
    for scheme in ["v1 scheme (JAR signing)", "v2 scheme (APK Signature Scheme v2)"]:
        if f"Verified using {scheme}: true" not in certificates:
            raise ValueError("APK 缺少兼容现有设备的 v1/v2 签名")


def verify(apk, version, build, build_tools):
    trusted = expected_certificate()
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version) or not re.fullmatch(r"[1-9][0-9]*", build):
        raise ValueError("发布版本格式不正确")
    if apk.name != f"CardWallet-Android-{build}.apk":
        raise ValueError("APK 文件名不符合更新通道约定")
    badging = subprocess.run([str(build_tools / "aapt2"), "dump", "badging", str(apk)],
                             check=True, capture_output=True, text=True).stdout
    certificates = subprocess.run([str(build_tools / "apksigner"), "verify", "--verbose", "--print-certs", str(apk)],
                                  check=True, capture_output=True, text=True).stdout
    validate_metadata(badging, certificates, version, build, trusted)


if __name__ == "__main__":
    try:
        if len(sys.argv) != 5:
            raise ValueError("用法：verify-release.py <APK> <版本> <版本编号> <Android build-tools 目录>")
        verify(Path(sys.argv[1]), sys.argv[2], sys.argv[3], Path(sys.argv[4]))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Android 发布校验失败：{error}", file=sys.stderr)
        sys.exit(1)
    print("APK 应用标识、版本、最低系统版本及新发布签名验证通过。")
