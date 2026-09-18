#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
build="$(mktemp -d)"
trap 'rm -rf "$build"' EXIT
for platform in ios macos; do
  domain="$root/apps/$platform/Domain"
  swiftc -O -D WALLET_CONTRACT_CLI \
    "$domain/CardJSONValue.swift" "$domain/CardModels.swift" "$domain/DataMigrationManager.swift" "$domain/SyncModels.swift" \
    "$domain/BankNameNormalizer.swift" "$domain/CardMetrics.swift" "$domain/CardCalendarRules.swift" \
    "$domain/DateCalculator.swift" "$domain/CardSearch.swift" "$domain/LocalCardPreferences.swift" "$domain/CardOperations.swift" "$domain/CardAttachmentPolicy.swift" "$root/apps/$platform/Tests/PlatformContractTests.swift" \
    "$root/scripts/contracts/LinuxLocalization.swift" "$root/scripts/contracts/main.swift" -o "$build/$platform-contracts"
  for zone in UTC America/Los_Angeles; do
    echo "Contract tests: $platform / $zone"
    TZ="$zone" WALLET_CONTRACT_DIR="$root/contracts/card-wallet/fixtures" "$build/$platform-contracts"
  done
done
