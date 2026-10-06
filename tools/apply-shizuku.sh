python3 - "$APP/build.gradle" "$ROOT/terminal/build.gradle" <<'PY'
from pathlib import Path
import sys
for arg in sys.argv[1:]:
    p=Path(arg)
    if not p.exists(): continue
    s=p.read_text()
    s=s.replace('compileSdk 37','compileSdk 36')
    s=s.replace('compileSdk 36','compileSdk 36')
    if 'targetSdk 37' in s:
        s=s.replace('targetSdk 37','targetSdk 36')
    p.write_text(s)
PY

#!/usr/bin/env bash
set -euo pipefail
ROOT="$PWD/upstream"
APP="$ROOT/app"
JAVA="$APP/src/main/java/com/zalexdev/stryker/utils"
grep -q 'dev.rikka.shizuku:api' "$APP/build.gradle" || \
  sed -i '/dependencies {/a\\    implementation "dev.rikka.shizuku:api:13.1.5"\n    implementation "dev.rikka.shizuku:provider:13.1.5"' "$APP/build.gradle"
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
    public static boolean isShellBackend() { return remoteUid() == 2000; }
    public static Process newShell() {
        if (hasPermission()) {
            try { return Shizuku.newProcess(new String[]{"/system/bin/sh"}, null, null); }
            catch (Throwable ignored) {}
        }
        try { return new ProcessBuilder("/system/bin/sh").redirectErrorStream(false).start(); }
        catch (Throwable ignored) { return null; }
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
python3 - "$APP/src/main/java/com/zalexdev/stryker/utils/Core.java" <<'PY'
from pathlib import Path
p=Path(__import__('sys').argv[1]); s=p.read_text()
s=s.replace('''    public void moveFile(@NonNull String source, @NonNull String destination){
        if (isRootless()) {
''','''    public void moveFile(@NonNull String source, @NonNull String destination){
        if (isRootless() && !ShizukuCompat.hasPermission()) {
''')
s=s.replace('''    public void deleteFile(@NonNull String file){
        if (isRootless()) {
''','''    public void deleteFile(@NonNull String file){
        if (isRootless() && !ShizukuCompat.hasPermission()) {
''')
s=s.replace('''    public void createFolder(@NonNull String folder){
        if (isRootless()) {
''','''    public void createFolder(@NonNull String folder){
        if (isRootless() && !ShizukuCompat.hasPermission()) {
''')
s=s.replace('''    public void chmodFolder(@NonNull String folder){
        if (isRootless()) return;
''','''    public void chmodFolder(@NonNull String folder){
        if (isRootless() && !ShizukuCompat.hasPermission()) return;
''')
s=s.replace('''    public void wpsDisableWifiIfEnabled(){
        if (isRootless()) return;
''','''    public void wpsDisableWifiIfEnabled(){
        if (isRootless() && !ShizukuCompat.hasPermission()) return;
''')
p.write_text(s)
PY

python3 - "$APP/build.gradle" <<'PY'
from pathlib import Path
p=Path(__import__('sys').argv[1]); s=p.read_text()
if 'versionName "6.5.0-shizuku"' not in s:
    s=s.replace('versionName "6.5.0"','versionName "6.5.0-shizuku"')
p.write_text(s)
PY

python3 - "$ROOT/terminal/build.gradle" <<'PY'
from pathlib import Path
p=Path(__import__('sys').argv[1])
s=p.read_text()
s=s.replace('\n  implementation "com.github.topjohnwu.libsu:core:5.0.4"\n','\n')
p.write_text(s)
PY

python3 - "$APP/src/main/res/layout/settings_main.xml" <<'PY'
from pathlib import Path
from sys import argv
p=Path(argv[1])
s=p.read_text()
card="""        <com.google.android.material.card.MaterialCardView
            android:id="@+id/privileged_access_card"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:layout_marginBottom="10dp"
            app:cardBackgroundColor="@color/light_contrast"
            app:cardCornerRadius="18dp"
            app:cardElevation="0dp"
            app:strokeColor="@color/light_lite_contrast"
            app:strokeWidth="1dp">
            <LinearLayout
                android:id="@+id/privileged_access_row"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:background="?attr/selectableItemBackground"
                android:clickable="true"
                android:focusable="true"
                android:gravity="center_vertical"
                android:minHeight="72dp"
                android:orientation="horizontal"
                android:padding="14dp">
                <ImageView
                    android:layout_width="44dp"
                    android:layout_height="44dp"
                    android:background="@drawable/settings_icon_bg"
                    android:padding="10dp"
                    android:src="@drawable/settings"
                    app:tint="@color/stryker_accent" />
                <LinearLayout
                    android:layout_width="0dp"
                    android:layout_height="wrap_content"
                    android:layout_marginStart="14dp"
                    android:layout_weight="1"
                    android:orientation="vertical">
                    <com.google.android.material.textview.MaterialTextView
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:text="Shizuku / Device Admin"
                        android:textColor="?android:attr/textColorPrimary"
                        android:textSize="16sp"
                        android:textStyle="bold" />
                    <com.google.android.material.textview.MaterialTextView
                        android:id="@+id/privileged_access_state"
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="2dp"
                        android:textColor="@color/grey"
                        android:textSize="12sp" />
                </LinearLayout>
                <ImageView
                    android:layout_width="20dp"
                    android:layout_height="20dp"
                    android:src="@drawable/arrow_right"
                    app:tint="@color/grey" />
            </LinearLayout>
        </com.google.android.material.card.MaterialCardView>

"""
needle='        <LinearLayout\n            android:id="@+id/engine_section"'
if 'android:id="@+id/privileged_access_card"' not in s:
    s=s.replace(needle,card+needle,1)
p.write_text(s)
PY

python3 - "$APP/src/main/java/com/zalexdev/stryker/settings/SettingsHomeFragment.java" <<'PY'
from pathlib import Path
from sys import argv
p=Path(argv[1]); s=p.read_text()
needle='        maxParCount.setText(String.valueOf(currentMaxPar()));'
code="""        View privilegedAccessRow = view.findViewById(R.id.privileged_access_row);
        TextView privilegedAccessState = view.findViewById(R.id.privileged_access_state);
        if (privilegedAccessRow != null && privilegedAccessState != null) {
            boolean shizuku = com.zalexdev.stryker.utils.ShizukuCompat.hasPermission();
            int uid = com.zalexdev.stryker.utils.ShizukuCompat.remoteUid();
            boolean admin = com.zalexdev.stryker.utils.DeviceAdminCompat.isActive(requireContext());
            String backend = uid == 0 ? "Shizuku root" : (uid == 2000 ? "Shizuku ADB" : "Shizuku unavailable");
            privilegedAccessState.setText(backend + (admin ? " · Device Admin active" : " · Device Admin inactive"));
            privilegedAccessRow.setOnClickListener(v -> {
                try {
                    startActivity(new android.content.Intent(requireContext(),
                            com.zalexdev.stryker.privileged.PrivilegedAccessActivity.class));
                } catch (Throwable ignored) {}
            });
        }
"""
if 'PrivilegedAccessActivity.class' not in s:
    s=s.replace(needle,needle+'\n'+code,1)
p.write_text(s)
PY

mkdir -p "$APP/src/main/java/com/zalexdev/stryker/privileged"
cat > "$APP/src/main/java/com/zalexdev/stryker/privileged/PrivilegedAccessActivity.java" <<'EOF'
package com.zalexdev.stryker.privileged;

import android.app.Activity;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.TextView;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.zalexdev.stryker.utils.DeviceAdminCompat;
import com.zalexdev.stryker.utils.ShizukuCompat;

public class PrivilegedAccessActivity extends Activity {
    private TextView status;
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(32,32,32,32);
        TextView title = new TextView(this);
        title.setText("Privileged access");
        title.setTextSize(26);
        title.setGravity(Gravity.CENTER_VERTICAL);
        root.addView(title);
        status = new TextView(this);
        status.setPadding(0,24,0,24);
        root.addView(status);
        MaterialButton shizuku = new MaterialButton(this);
        shizuku.setText("Request Shizuku permission");
        shizuku.setOnClickListener(v -> ShizukuCompat.requestPermission(6505));
        root.addView(shizuku);
        MaterialButton admin = new MaterialButton(this);
        admin.setText("Enable Device Admin");
        admin.setOnClickListener(v -> startActivity(DeviceAdminCompat.activationIntent(this)));
        root.addView(admin);
        setContentView(root);
        refresh();
    }
    @Override protected void onResume() { super.onResume(); refresh(); }
    private void refresh() {
        boolean running=ShizukuCompat.isRunning();
        boolean granted=ShizukuCompat.hasPermission();
        int uid=ShizukuCompat.remoteUid();
        boolean admin=DeviceAdminCompat.isActive(this);
        String backend=uid==0 ? "root (UID 0)" : (uid==2000 ? "ADB shell (UID 2000)" : "unavailable");
        status.setText("Shizuku: "+(running ? "running" : "stopped")+
                "\nPermission: "+(granted ? "granted" : "not granted")+
                "\nBackend: "+backend+
                "\nDevice Admin: "+(admin ? "active" : "inactive"));
    }
}
EOF

python3 - "$APP/src/main/AndroidManifest.xml" <<'PY'
from pathlib import Path
from sys import argv
p=Path(argv[1]); s=p.read_text()
activity='''        <activity
            android:name=".privileged.PrivilegedAccessActivity"
            android:exported="false"
            android:label="Privileged access" />
'''
if 'android:name=".privileged.PrivilegedAccessActivity"' not in s:
    s=s.replace('        <activity\n            android:name=".utils.LicenseActivity"',activity+'\n        <activity\n            android:name=".utils.LicenseActivity"',1)
p.write_text(s)
PY

cat >> "$APP/proguard-rules.pro" <<'EOF'
-keep class com.zalexdev.stryker.privileged.PrivilegedAccessActivity { *; }
EOF

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

cat > "$APP/src/main/res/xml/stryker_device_admin.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<device-admin xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-policies>
        <force-lock />
    </uses-policies>
</device-admin>
EOF

cat > "$JAVA/DeviceAdminCompat.java" <<'EOF'
package com.zalexdev.stryker.utils;
import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import com.zalexdev.stryker.admin.StrykerDeviceAdminReceiver;
public final class DeviceAdminCompat {
    private DeviceAdminCompat() {}
    public static ComponentName component(Context c) {
        return new ComponentName(c, StrykerDeviceAdminReceiver.class);
    }
    public static boolean isActive(Context c) {
        try {
            DevicePolicyManager dpm=(DevicePolicyManager)c.getSystemService(Context.DEVICE_POLICY_SERVICE);
            return dpm != null && dpm.isAdminActive(component(c));
        } catch (Throwable ignored) { return false; }
    }
    public static Intent activationIntent(Context c) {
        Intent i=new Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN);
        i.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, component(c));
        i.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Optional Stryker device-management capability. This does not grant root.");
        return i;
    }
}
EOF

mkdir -p "$APP/src/main/java/com/zalexdev/stryker/admin"
cat > "$APP/src/main/java/com/zalexdev/stryker/admin/StrykerDeviceAdminReceiver.java" <<'EOF'
package com.zalexdev.stryker.admin;
import android.app.admin.DeviceAdminReceiver;
public class StrykerDeviceAdminReceiver extends DeviceAdminReceiver {}
EOF

python3 - "$APP/src/main/AndroidManifest.xml" <<'PY'
from pathlib import Path
from sys import argv
p=Path(argv[1]); s=p.read_text()
receiver='''        <receiver
            android:name=".admin.StrykerDeviceAdminReceiver"
            android:description="@string/app_name"
            android:exported="true"
            android:label="@string/app_name"
            android:permission="android.permission.BIND_DEVICE_ADMIN">
            <meta-data
                android:name="android.app.device_admin"
                android:resource="@xml/stryker_device_admin" />
            <intent-filter>
                <action android:name="android.app.action.DEVICE_ADMIN_ENABLED" />
            </intent-filter>
        </receiver>
'''
if 'StrykerDeviceAdminReceiver' not in s:
    s=s.replace('        <provider\\n            android:name="androidx.core.content.FileProvider"', receiver+'\\n        <provider\\n            android:name="androidx.core.content.FileProvider"',1)
p.write_text(s)
PY

cat >> "$APP/proguard-rules.pro" <<'EOF'

# Shizuku / device-admin entry points.
-keep class rikka.shizuku.** { *; }
-keep class moe.shizuku.** { *; }
-keep class com.zalexdev.stryker.admin.StrykerDeviceAdminReceiver { *; }
EOF

python3 - "$APP/src/main/java/com/zalexdev/stryker/utils/Core.java" <<'PY'
from pathlib import Path
p=Path(__import__('sys').argv[1]); s=p.read_text()
s=s.replace('return "no root access — su did not return a root shell";',
            'return "no privileged backend — start Shizuku and grant Stryker permission, or use the rootless engine";')
p.write_text(s)
PY
