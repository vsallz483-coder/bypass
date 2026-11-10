# CFS Linkbuster (APK)

Flutter + WebView ke https://cfslinkbuster.vercel.app/
- Splash animasi logo CFS (zoom, fade, loading bar, min ~3 detik)
- Dialog confirm()/alert() website diganti dialog modern
- Link tujuan dibuka di browser HP
- APK dibuild otomatis oleh GitHub Actions (push ke main)

Ganti URL website: edit `kSiteUrl` di `lib/main.dart`.
Folder `android/` dibuat otomatis oleh workflow, jangan di-commit.
