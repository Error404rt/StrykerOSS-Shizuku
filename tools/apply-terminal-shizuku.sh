#!/usr/bin/env bash
set -euo pipefail
ROOT="$PWD/upstream"
MOD="$ROOT/terminal"
SRC="$MOD/src/main/java/com/stryker/terminal/ui/other"
grep -q 'dev.rikka.shizuku:api' "$MOD/build.gradle" || \
  sed -i '/dependencies {/a\\  implementation "dev.rikka.shizuku:api:12.2.0"\n  implementation "dev.rikka.shizuku:provider:12.2.0"' "$MOD/build.gradle"
mkdir -p "$SRC"
cat > "$SRC/ShizukuCompat.java" <<'EOF'
package com.stryker.terminal.ui.other;
import android.content.pm.PackageManager;
import rikka.shizuku.Shizuku;
public final class ShizukuCompat {
    private ShizukuCompat() {}
    private static boolean allowed() {
        try { return Shizuku.pingBinder()
                && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED; }
        catch (Throwable ignored) { return false; }
    }
    public static Process newShell() {
        if (!allowed()) return null;
        try { return Shizuku.newProcess(new String[]{"/system/bin/sh"}, null, null); }
        catch (Throwable ignored) { return null; }
    }
}
EOF
python3 - "$SRC/SuUtils.java" <<'PY'
from pathlib import Path
p=Path(__import__('sys').argv[1])
s=p.read_text()
s=s.replace('Runtime.getRuntime().exec("su")','ShizukuCompat.newShell()')
p.write_text(s)
PY
