# 📂 Raw Analysis Artifacts Summary — PikaShow APK

## 📌 Overview
Yeh document `pikashow_raw_reports.zip` se extract ki gayi تمام 16 raw analysis files ka technical index aur findings summary provide karta hai. Yeh files `D:\Reverse Engineer movie app\01_REVERSE_ENGINEERING\PikaShow\raw_reports\` directory mein mojood hain.

---

## 📑 Artifacts Index & Data Catalog

| File Name | File Size | Tool Source | Description & Content |
| :--- | :---: | :--- | :--- |
| **`JAVA_DECOMPILE_STATUS.md`** | 8.1 KB | JADX + APKTool | Complete decompilation log, environment details, OpenJDK 21 setup, and success/failure counts. |
| **`manifest_summary.txt`** | 8.0 KB | APKTool 2.11.0 | Parsed AndroidManifest summary: Identity, permissions, intent filters, activities, and services. |
| **`apktool_AndroidManifest.xml`**| 23.2 KB | APKTool 2.11.0 | Full decoded XML manifest with human-readable tags and attributes. |
| **`AndroidManifest_decoded.xml`** | 18.7 KB | Androguard 4.1.4 | Independent secondary manifest decode for cross-verification. |
| **`certificate.txt`** | 727 B | OpenJDK Keytool | APK signing certificate details: generic Android Debug keystore, fingerprints, and validity dates. |
| **`certificate_androguard.txt`** | 2.2 KB | Androguard 4.1.4 | Androguard certificate parser output (X.509 structure, public key details). |
| **`androguard_info.json`** | 4.9 KB | Androguard 4.1.4 | Machine-readable JSON containing package name, SDK versions, permissions, and main activities. |
| **`dex_packages_top.txt`** | 869 B | DEX Parser | Class counts by top package names (e.g. Mintegral `3,123`, Google `1,781`, Unity `1,171`, AppLovin `772`). |
| **`dex_urls.txt`** | 5.6 KB | DEX String Scan | Complete list of all HTTP/HTTPS URL strings found across `classes.dex` and `classes2.dex`. |
| **`urls.txt`** | 5.6 KB | Full String Dump| Consolidated unique URLs from DEX files and `libpika.so`. |
| **`domains.txt`** | 1.5 KB | Domain Extractor| Frequency count of domains found in binary strings (dominated by ad networks). |
| **`native_libs.txt`** | 2.5 KB | Archive Extractor| Complete file paths and sizes of `.so` libraries across 4 ABIs (`arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`). |
| **`assets_list.txt`** | 4.5 KB | APK Unpacker | Complete listing of assets folder, including 8.1 MB chunked payload under `assets/z/`. |
| **`jadx_packages.txt`** | 2.4 KB | JADX 1.5.3 | Package tree listing from JADX decompilation (1,047 packages). |
| **`jadx_file_count.txt`** | 286 B | JADX 1.5.3 | File count stats: 12,659 `.java` files produced across 9,474 classes. |
| **`jadx.log`** | 6.6 KB | JADX 1.5.3 | Full stdout/stderr execution log from JADX engine. |

---

## 📊 Summary of Crucial Findings from Raw Data

### 1. Dominant Third-Party Code Volume:
From `dex_packages_top.txt`:
```
3123    com/mbridge/msdk (Mintegral Ad SDK)
1781    com/google/android (Play Services, Firebase)
1171    com/unity3d/ads
1080    com/unity3d/services
772     com/applovin/impl
698     com/vungle/ads
628     gatewayprotocol/v1
478     com/google/protobuf
...
71      com/offshore/raichu (App's own code)
```

### 2. Native Library Manifest:
From `native_libs.txt`:
```
lib/arm64-v8a/libpika.so                       (1,061,760 bytes)
lib/arm64-v8a/libapplovin-native-crash-reporter.so (867,944 bytes)
lib/arm64-v8a/libandroidx.graphics.path.so     (10,096 bytes)
lib/arm64-v8a/libdatastore_shared_counter.so   (7,112 bytes)
```
Identical 4 libraries exist for `armeabi-v7a`, `x86`, and `x86_64`.

### 3. Signing Certificate Fingerprint:
From `certificate.txt`:
```
Owner / Issuer: C=US, O=Android, CN=Android Debug
SHA-1:   A2:F3:9A:9D:C1:12:87:9E:38:65:ED:1B:07:0F:CC:4C:26:4B:EA:D6
SHA-256: F6:14:BF:F7:BC:30:2B:71:25:C5:85:FD:FA:48:D5:DA:9E:24:B5:2F:40:83:99:3F:91:72:F6:7D:3D:C8:BE:6C
```

