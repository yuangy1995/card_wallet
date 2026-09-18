#!/usr/bin/env python3
"""固定并核验发布标签，只允许指向本次已检出的提交，不移动已有标签。"""
import argparse
import json
import re
import subprocess
import sys

REPOSITORY = 'yuangy1995/card_wallet'


def api(path, values=None):
    command = ['gh', 'api', f'repos/{REPOSITORY}/{path}']
    if values is not None:
        command += ['--method', 'POST']
        for name, value in values.items():
            command += ['-f', f'{name}={value}']
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def checkout_sha():
    return subprocess.run(['git', 'rev-parse', 'HEAD'], check=True,
                          capture_output=True, text=True).stdout.strip()


def validate(tag, sha):
    if not re.fullmatch(r'(android|mac)-v[0-9]+\.[0-9]+\.[0-9]+-[1-9][0-9]*', tag):
        raise ValueError('发布标签格式不正确。')
    if not re.fullmatch(r'[0-9a-f]{40}', sha) or checkout_sha() != sha:
        raise ValueError('发布提交与实际检出的源码不一致。')


def tag_object(tag):
    refs = api(f'git/matching-refs/tags/{tag}')
    matches = [ref for ref in refs if ref['ref'] == f'refs/tags/{tag}']
    if len(matches) > 1:
        raise ValueError('发布标签不唯一。')
    return matches[0]['object'] if matches else None


def require_same_commit(obj, sha):
    if not obj or obj['type'] != 'commit' or obj['sha'] != sha:
        raise ValueError('发布标签不存在或指向其他提交；禁止覆盖、移动标签或发布未经验证的源码。')


def verify(tag, sha):
    validate(tag, sha)
    require_same_commit(tag_object(tag), sha)


def pin(tag, sha):
    validate(tag, sha)
    existing = tag_object(tag)
    if existing:
        require_same_commit(existing, sha)
        return
    head = api('git/ref/heads/main')['object']
    if head['type'] != 'commit' or head['sha'] != sha:
        raise ValueError('主线已更新，尚未创建发布标签。请从最新 main 重新触发发布。')
    api('git/refs', {'ref': f'refs/tags/{tag}', 'sha': sha})
    # 重新读取而非仅信任创建请求的返回值；后续上传和公开前也会再核验。
    require_same_commit(tag_object(tag), sha)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['pin', 'verify'])
    parser.add_argument('tag')
    parser.add_argument('sha')
    args = parser.parse_args()
    try:
        (pin if args.operation == 'pin' else verify)(args.tag, args.sha)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, KeyError, TypeError, subprocess.CalledProcessError):
        print('无法安全确认远端发布标签；检查仓库权限与网络，未输出凭据。', file=sys.stderr)
        return 1
    print(f'发布标签 {args.tag} 已固定并核验为源码 {args.sha[:12]}。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
