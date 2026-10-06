#!/usr/bin/env bash
set -euo pipefail
ROOT="$PWD/upstream"
APP="$ROOT/app"
JAVA="$APP/src/main/java/com/zalexdev/stryker/utils"
grep -q 'dev.rikka.shizuku:api' "$APP/build.gradle" || \
  sed -i '/dependencies {/a\\    implementation "dev.rikka.shizuku:api:12.2.0"\n    implementation "dev.rikka.shizuku:provider:12.2.0"' "$APP/build.gradle"
python3 - "$APP/src/main/AndroidManifest.xml" <<'PY'
from pathlib import Path
from sys import argv
p=Path(argv[1]); s=p.read_text()
perm='    <uses-permission android:name="moe.shizuku.manager.permission.API_V23" />\n'
if 'moe.shizuku.manager.permission.API_V23' not in s:
    s=s.replace('    <uses-permission android:name="android.permission.VIBRATE" />\n',
                '    <uses-permission android:name="android.permission.VIBRATE" />\n'+perm)
provider='''        <provider
            android:name="rikka.shizuku.ShizukuProvider"
            android:authorities="$''' + '''{applicationId}.shizuku"
            android:enabled="true"
            android:exported="true"
            android:multiprocess="false"
            android:permission="android.permission.INTERACT_ACROSS_USERS_FULL" />
'''
if 'rikka.shizuku.ShizukuProvider' not in s:
    s=s.replace('        <property\n            android:name="android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"',
                provider+'\n        <property\n            android:name="android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"')
p.write_text(s)
PY
mkdir -p "$JAVA"
cat > "$JAVA/ShizukuCompat.java" <<'EOF'
package com.zalexdev.stryker.utils;
import android.content.pm.PackageManager;
import rikka.shizuku.Shizuku;
public final class ShizukuCompat {
    private ShizukuCompat() {}
    public static boolean isRunning() { try { return Shizuku.pingBinder(); } catch (Throwable ignored) { return false; } }
    public static boolean hasPermission() {
        try { return isRunning() && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED; }
        catch (Throwable ignored) { return false; }
    }
    public static int remoteUid() { try { return Shizuku.getUid(); } catch (Throwable ignored) { return -1; } }
    public static boolean isRootBackend() { return remoteUid() == 0; }
    public static Process newShell() {
        if (!hasPermission()) return null;
        try { return Shizuku.newProcess(new String[]{"/system/bin/sh"}, null, null); }
        catch (Throwable e) { return null; }
    }
    public static Process newProcess(String[] command) {
        if (!hasPermission()) return null;
        try { return Shizuku.newProcess(command, null, null); }
        catch (Throwable e) { return null; }
    }
    public static void requestPermission(int requestCode) {
        if (!isRunning()) return;
        try {
            if (Shizuku.checkSelfPermission() != PackageManager.PERMISSION_GRANTED) Shizuku.requestPermission(requestCode);
        } catch (Throwable ignored) {}
    }
}
EOF
python3 - "$APP/src/main/java" <<'PY'
from pathlib import Path
import sys
for p in Path(sys.argv[1]).rglob('*.java'):
    s=p.read_text(errors='ignore'); old=s
    s=s.replace('Runtime.getRuntime().exec("su -mm")','com.zalexdev.stryker.utils.ShizukuCompat.newShell()')
    s=s.replace('Runtime.getRuntime().exec("su")','com.zalexdev.stryker.utils.ShizukuCompat.newShell()')
    if s != old: p.write_text(s)
PY
python3 - "$APP/src/main/java/com/zalexdev/stryker/StrykerApp.java" <<'PY'
from pathlib import Path
p=Path(__import__('sys').argv[1])
s=p.read_text()
needle='        super.onCreate();'
replacement='''        super.onCreate();
        try {
            rikka.shizuku.Shizuku.addBinderReceivedListenerSticky(
                    () -> com.zalexdev.stryker.utils.ShizukuCompat.requestPermission(6505));
        } catch (Throwable ignored) {}
'''
if 'ShizukuCompat.requestPermission(6505)' not in s:
    s=s.replace(needle, replacement, 1)
p.write_text(s)
PY

python3 - "$APP/src/main/java/com/zalexdev/stryker/utils/Core.java" <<'PY'
from pathlib import Path
p=Path(__import__('sys').argv[1]); s=p.read_text()
s=s.replace('return "no root access — su did not return a root shell";',
            'return "no privileged backend — start Shizuku and grant Stryker permission, or use the rootless engine";')
p.write_text(s)
PY
