# 📱 PikaShow Reverse Engineering & Security Audit Dossier

Yeh directory PikaShow APK (`com.offshore.pikachu`, version `10.8.2`) ke static analysis, architecture teardown, aur raw reports ka complete documentation hub hai.

---

## 📑 Documentation Index

| File | Purpose |
| :--- | :--- |
| **[`Pikashow_Reverse_Engineering_Report.md`](file:///d:/Reverse%20Engineer%20movie%20app/Pikashow_Reverse_Engineering_Report.md)** | Full 11-Page Converted PDF Report (Metrics, Findings, Methodology, Risk Summary). |
| **[`architecture.md`](file:///d:/Reverse%20Engineer%20movie%20app/01_REVERSE_ENGINEERING/PikaShow/architecture.md)** | App Structure, 46-Class Thin Shell, Room SQLite Cache, and JNI Bridge. |
| **[`backend_analysis.md`](file:///d:/Reverse%20Engineer%20movie%20app/01_REVERSE_ENGINEERING/PikaShow/backend_analysis.md)** | Network Indicators, Retrofit 2, `libpika.so` Request Signing, and Domains. |
| **[`security_and_provenance.md`](file:///d:/Reverse%20Engineer%20movie%20app/01_REVERSE_ENGINEERING/PikaShow/security_and_provenance.md)** | Debug Keystore Audit, Cleartext HTTP Flags, and Exported Service Vulnerabilities. |
| **[`raw_artifacts_summary.md`](file:///d:/Reverse%20Engineer%20movie%20app/01_REVERSE_ENGINEERING/PikaShow/raw_artifacts_summary.md)** | Technical Index of all 16 Raw Outputs extracted from `pikashow_raw_reports.zip`. |
| **[`raw_reports/`](file:///d:/Reverse%20Engineer%20movie%20app/01_REVERSE_ENGINEERING/PikaShow/raw_reports/)** | Directory containing the uncompressed 16 raw parser outputs (XML, JSON, TXT). |

---

## 📊 Summary of Headline Metrics
* **Total Binary Classes:** `17,357`
* **App's Own Code:** `46` Java files under `com.offshore.raichu`
* **Ad & Tracker Volume:** ~99.7% of code belongs to AppLovin MAX, Unity Ads, Vungle, Mintegral, and Firebase.
* **Signing Key:** Generic Android Debug Key (Non-release build).
* **Native Module:** `libpika.so` manages JNI header generation (`pikachu_get_headers_v2`).

