#!/bin/bash
# Focused maintenance checks available with Command Line Tools. Not a substitute
# for make check/XCTest. The cursor lifecycle check briefly creates a 1-point panel.
set -euo pipefail
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d -t crisp-maintenance-checks)
trap 'rm -rf "$check_dir"' EXIT

compile_check() {
    local name="$1" source="$2" check="$3"
    swiftc -warnings-as-errors -swift-version 6 -parse-as-library "$source" "$check" -o "$check_dir/$name"
}

compile_check routing Crisp/Models/BrightnessDisplayRouting.swift scripts/check-brightness-routing.swift
compile_check ddc Crisp/Models/DDCTransport.swift scripts/check-ddc-transport.swift
compile_check layout Crisp/Models/DefaultDisplaySetup.swift scripts/check-dell-workarounds.swift
compile_check origins Crisp/Models/DisplayOrigins.swift scripts/check-display-origins.swift
compile_check options Crisp/Models/MirrorWorkaroundOptions.swift scripts/check-mirror-options.swift
compile_check completion Crisp/Services/CGHelpers.swift scripts/check-cg-completion.swift
compile_check cursor Crisp/Services/MirroredCursorRefreshService.swift scripts/check-mirrored-cursor-refresh.swift

for pass in 1 2 3; do
    echo "Maintenance checks: pass $pass of 3"
    for name in routing ddc layout origins options completion cursor; do
        "$check_dir/$name"
    done
done
