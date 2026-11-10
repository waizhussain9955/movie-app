# JAVA_DECOMPILE_STATUS.md — Pikashow APK (Java-based decompile)

Date: 2026-11-10 (PKT). Work dir: `/home/hatch/workspace/reverse-engineering/pikashow/work/`
Source APK: `/home/hatch/workspace/user/files/pikashow_0_v8n4.apk` (21,434,649 bytes) — **not modified**.
Working copy: `work/pikashow.apk`, SHA256 `372dc5af73e2299ed4a65c0567a3a2ecb3ce6c7ce850d06f4d3c29faf3a4e0a6` (matches the given hash).

## Note on the repo

`awesome-reverse-engineer-anything` (AIshihzong) is **only an awesome-list** about
morluto/rea — it is not a decompiler and contains no decompilation tooling itself.
Its README states it is unofficial / not affiliated with morluto/rea. The real REA is
morluto/rea (npm `rea-agents`), which orchestrates JADX/Ghidra/Hopper/IDA for an agent.
This decompile was therefore done directly with the underlying tools (jadx + apktool),
which is exactly what REA would orchestrate. No REA/rea-agents install was needed.

## What succeeded

- **Java install: OK.** `apt-get update && apt-get install -y default-jdk-headless`
  succeeded on Ubuntu 24.04 → OpenJDK 21.0.13 (21.0.13.0.3+1-1~24.04.1-Ubuntu).
  `java -version` verified. (One apt warning only: nodesource InRelease fetch failed,
  ignored — Ubuntu mirrors worked.) No Temurin fallback needed. `keytool` available.
- **jadx 1.5.3: OK.** Downloaded `jadx-1.5.3.zip` (112 MB) from
  github.com/skylot/jadx/releases/download/v1.5.3/ → `tools/jadx-1.5.3/`.
  Ran `jadx -d work/jadx_out --show-bad-code -j 2 work/pikashow.apk` — completed
  9,474 classes. Full log: `work/reports/jadx.log`.
- **apktool 2.11.0: OK (after one retry).** First download from bitbucket was truncated
  (19,027,414 of 24,480,507 bytes → "Invalid or corrupt jarfile"); resumed with
  `curl -L -C -` and verified `java -jar apktool_2.11.0.jar --version` → `2.11.0`.
  Jar at `tools/apktool_2.11.0.jar` (+ `tools/apktool.jar` copy, `tools/apktool` wrapper).
  Ran `apktool d -f -o work/apktool_out work/pikashow.apk` — success, all stages
  (baksmali classes.dex + classes2.dex, resource table, manifest decode).
- **jadx output: 12,659 `.java` files** (9,474 classes; more files than classes because
  inner/anonymous classes are split out), 83 MB sources + 26 MB resources = 108 MB total.
  1,047 distinct packages. App-own code is small: `com/offshore/raichu` = **46 .java files**,
  and none of them carry jadx WARN markers (clean decompile).
  Smali cross-check: apktool produced 17,357 `.smali` files.
- **Manifest extraction: OK** — see `reports/manifest_summary.txt` and
  `reports/apktool_AndroidManifest.xml` (decoded copy of `work/apktool_out/AndroidManifest.xml`).
- **Certificate: OK** — `keytool -printcert` on `META-INF/ANDROIDD.RSA` →
  `reports/certificate.txt`. **Signed with the generic Android Debug certificate**
  (Owner/Issuer `C=US, O=Android, CN=Android Debug`, serial `35d0ca3017725cd4`,
  valid 2025-05-23 → 2052-10-08, SHA256 fingerprint
  `F6:14:BF:F7:BC:30:2B:71:25:C5:85:FD:FA:48:D5:DA:9E:24:B5:2F:40:83:99:3F:91:72:F6:7D:3D:C8:BE:6C`).
  A debug-signed APK is a notable trust/red flag for a distributed app.
- **Strings/URLs: OK** — `strings` on classes.dex + classes2.dex + libpika.so (arm64-v8a).
  `reports/urls.txt` = **102 unique URLs** (task asked top 200; only 102 distinct URLs exist
  in those inputs). `reports/domains.txt` (extra) = per-domain counts.
  Finding: almost all plaintext URLs belong to ad/analytics SDKs (AppLovin, Vungle,
  Unity Ads, Firebase/Google). No plaintext Pikashow backend/API base URL was found in
  the dex or libpika.so strings — the app's own endpoints are likely fetched via
  Firebase Remote Config / encrypted native code / the obfuscated `assets/z/*.ext` blobs.
- **Native libs: OK** — `reports/native_libs.txt`. 4 ABIs × 4 .so files each
  (arm64-v8a, armeabi-v7a, x86, x86_64): `libpika.so` (~1.1 MB arm64, the app's own native
  lib), `libapplovin-native-crash-reporter.so`, `libandroidx.graphics.path.so`,
  `libdatastore_shared_counter.so`.
- **Assets: OK** — `reports/assets_list.txt` (107 lines). Notables: `assets/z/` holds
  ~50 × 100 KB `eee*.ext` chunks + 4 × 1 MB `em*.ext` + `f*.ext`/`ggg*.ext` (obfuscated/
  split payload, stored uncompressed), `assets/ad-viewer/` (OMID JS), `assets/builddatas.json`.

## What failed / caveats

- **jadx finished with errors, count: 44** (final log line; no per-class error lines are
  emitted in the log). These are 44 of 9,474 classes that did not decompile cleanly
  (obfuscated/third-party code; `--show-bad-code` kept best-effort output in place).
  37 files contain `/* JADX WARN: ... */` markers. App-own `com/offshore/raichu`
  files are unaffected (no markers).
- **jadx CLI flag**: `--threads` does not exist in jadx 1.5.3; correct flag is
  `-j / --threads-count` (used `-j 2`).
- **apktool first download truncated** (see above); fixed by resume, no fallback needed.
- `apksigner` was not installed/used; certificate was read via `keytool` instead (sufficient).
- Pre-existing files in `work/reports/` timestamped 00:30 (e.g. `androguard_info.json`,
  `dex_classes.txt`, `dex_strings_all.txt`, `certificate_androguard.txt`,
  `AndroidManifest_decoded.xml`, `dex_packages_top.txt`, `dex_urls.txt`) were created by
  a separate/concurrent agent run, not by this Java-decompile task — left untouched.

## Tool versions

- Java: OpenJDK 21.0.13 (default-jdk-headless, Ubuntu 24.04)
- jadx: 1.5.3 (`tools/jadx-1.5.3/bin/jadx`)
- apktool: 2.11.0 (`tools/apktool_2.11.0.jar`, 24,480,507 bytes)
- keytool / strings: system (OpenJDK 21 / binutils)

## Manifest key facts

- Package: `com.offshore.pikachu` | Version: **10.8.2 (versionCode 83)**
- minSdk 21 (Android 5.0), targetSdk 34, compileSdk 34 (Android 14)
- Application class: `com.offshore.raichu.MyApplication`
- Launcher activity: `com.offshore.raichu.MainActivity` (only exported activity)
- Permissions: **15 uses-permission + 1 declared (signature) custom permission**
  (INTERNET, ACCESS_NETWORK_STATE, RECORD_AUDIO, AD_ID, ACCESS_ADSERVICES_*,
  ACCESS_WIFI_STATE, WAKE_LOCK, RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE, …)
- Components: **31 activities** (only 2 app-own: MainActivity, WebViewActivity;
  rest are AppLovin MAX / Unity Ads / Vungle / Mintegral ad activities),
  **12 services** (1 app-own: `RequestService`, exported, action `com.offshore.REQUEST_SERVICE`),
  **12 receivers, 4 providers** (all Firebase/WorkManager/AppLovin/Vungle/AndroidX — none app-own).
- `usesCleartextTraffic=true`, `allowBackup=true`, `largeHeap=true`.
- Ad/analytics SDKs in manifest: AppLovin MAX, Unity Ads, Vungle, Mintegral (mbridge),
  Firebase (Analytics/Crashlytics/Remote Config/Sessions).

## Top jadx packages (by .java count; full list in reports/jadx_packages.txt)

1. com.google.android.gms.internal.measurement — 421
2. com.google.protobuf — 328
3. com.applovin.impl — 270
4. com.google.android.gms.measurement.internal — 240
5. gatewayprotocol.v1 — 220 (Mintegral)
6. com.unity3d.ads.core.domain — 206
7. com.vungle.ads — 126
8. com/offshore/raichu (app-own) — 45 (+1 R.java under com/offshore/pikachu = 46 total)

## Output files (this task)

- `work/apktool_out/` — full apktool decode (AndroidManifest.xml, res/, smali/, assets/, lib/, …)
- `work/jadx_out/` — full jadx decompile (`sources/` 12,659 .java files, `resources/`)
- `work/reports/apktool_AndroidManifest.xml` — decoded manifest copy
- `work/reports/manifest_summary.txt` — package/version/SDK/permissions/components (131 lines)
- `work/reports/certificate.txt` — keytool printcert (debug cert)
- `work/reports/urls.txt` — 102 unique URLs from dex + libpika.so
- `work/reports/domains.txt` — per-domain counts (extra)
- `work/reports/native_libs.txt` — native libs per ABI
- `work/reports/assets_list.txt` — assets listing
- `work/reports/jadx_packages.txt` — top 100 packages (of 1,047)
- `work/reports/jadx_file_count.txt` — counts (12,659 .java / 9,474 classes / 44 errors)
- `work/reports/jadx.log` — full jadx run log
- `work/reports/JAVA_DECOMPILE_STATUS.md` — this file
- Tools: `tools/jadx-1.5.3/`, `tools/apktool_2.11.0.jar`, `tools/apktool`, `tools/apktool.jar`
