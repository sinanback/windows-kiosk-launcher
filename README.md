# Windows Kiosk Launcher

**Bir web uygulaması. Ayrı bir Chrome profili. Kiosk odaklı bir Windows oturumu.**  
**One web app. A dedicated Chrome profile. A kiosk-focused Windows session.**

`Windows x64` · `Chrome` · `.NET 8` · `PowerShell` · `1.1.4 public preview`

[Türkçe](#turkce) · [English](#english) · [İndir / Download](https://github.com/sinanback/windows-kiosk-launcher/releases)

<a id="turkce"></a>
## Türkçe

### Proje hakkında
Windows Kiosk Launcher, yapılandırılan web adresini Chrome'un kiosk modunda açmak için hazırlanmış bir Windows uygulama paketidir. Karşılama ekranları, dokunmatik terminaller ve tek web uygulamasına odaklanan ortak kullanım cihazları için tasarlanmıştır.

Bu depo **kurulum/kaldırma betiklerini ve örnek yapılandırmayı** içerir. Çalıştırılabilir uygulamalar **Releases** bölümündeki ZIP paketindedir. Uygulamaların özgün C# kaynak kodları mevcut olmadığı için bu depo tam kaynak koddan yeniden derleme sunmaz.

### Özellikler
Paketin mevcut kullanım kılavuzu aşağıdaki çalışma davranışlarını tanımlar; genel dağıtım kopyası için canlı kiosk testi henüz yapılmamıştır:

- Yapılandırılabilir web adresiyle tam ekran Chrome kiosk oturumu.
- Chrome kapandığında ayarlanabilir gecikmeyle yeniden başlatma.
- Kişisel Chrome profilinden ayrı kiosk profili.
- **Ctrl+5** ile kiosk döngüsünden çıkış ve masaüstüne dönüş.
- Dokunmatik klavye, görev çubuğu görünürlüğü ve çok parmaklı touchpad hareketleri için seçenekler.
- Yaygın sistem ve tarayıcı kısayollarını kısıtlama seçeneği.

Kurulum betiği, seçilen kullanıcı için oturum açılışında çalışan **Limited** yetkili bir zamanlanmış görev oluşturur, masaüstü/Başlat menüsü kısayollarını ekler ve mevcut kurulumun yapılandırmasını korur.

### İndirme ve kurulum
1. [Releases](https://github.com/sinanback/windows-kiosk-launcher/releases) bölümünden **WindowsKiosk-1.1.4-public.1.zip** paketini indirin. GitHub'ın otomatik **Source code** ZIP'i çalıştırılabilir dosyaları içermez.
2. ZIP'i kalıcı bir klasöre çıkarın. Chrome'un kurulu olması gerekir.
3. Paket kökündeki `config.json` dosyasında `Url` değerini kendi web uygulamanızın adresiyle değiştirin. Varsayılan `https://example.com/` yalnızca örnektir.
4. `Kur.cmd` dosyasını çalıştırın. Kurulum yönetici izni ister; program dosyalarını ve Windows ilkesini değiştirir.
5. Ekran kenarı hareketi ilkesinin uygulanması için Windows'u yeniden başlatın. Kiosk oturum açılışında çalışır; **Kiosk Baslat** kısayoluyla da başlatılabilir.
6. Çıkmak için **Ctrl+5** kullanın. Kurulumdan sonraki ayarlar `%ProgramData%\WindowsKioskLauncher\config.json` dosyasından değiştirilir.

İlk denemeyi ayrı bir test hesabında yapın. Bu genel dağıtım kopyası, uygulama içindeki sabit varsayılan adresi örnek adresle değiştirilmiş bir **ön sürümdür**; üretim cihazında kullanım öncesinde kurulum, çıkış ve kaldırma akışlarını doğrulayın.

### Yapılandırma
| Alan | İşlev |
|---|---|
| `Url` | Açılacak HTTP/HTTPS web adresi. |
| `BrowserPath` | Otomatik bulunamazsa `chrome.exe` tam yolu; varsayılan `null`. |
| `ChromeProfileDirectory` | Kioska ayrılmış Chrome profil klasörü. |
| `StartDelaySeconds` | Başlangıç beklemesi; paket kılavuzundaki aralık 0–300 saniye. |
| `RestartDelaySeconds` | Yeniden başlatma beklemesi; paket kılavuzundaki aralık 1–300 saniye. |
| `UseModernTouchKeyboard` | Modern dokunmatik klavye ve Explorer ile çalışma seçeneği. |
| `KillExplorer` | Modern klavye kapalıyken Explorer'ı sonlandırma seçeneği. |
| `RestoreExplorerOnExit` | Çıkışta Explorer'ı geri açma seçeneği. |
| `BlockSystemKeys` | Yaygın sistem/tarayıcı kısayollarını kısıtlama. |
| `DisableMultiFingerTouchpadGestures` | Çok parmaklı Precision Touchpad hareketlerini kısıtlama. |
| `AdditionalChromeArguments` | Her öğesi ayrı bir Chrome komut satırı argümanı olan liste. |

Yapılandırmayı değiştirdikten sonra kiosk oturumunu kapatıp yeniden başlatın. Güncelleme kurulumu mevcut yapılandırmayı korur; bu nedenle paket içindeki örneği değiştirmek, daha önce kurulu bir kopyanın adresini değiştirmez.

### Sistem değişiklikleri, veriler ve kaldırma
- Kurulum dosyaları: `%ProgramFiles%\WindowsKioskLauncher`.
- Yapılandırma ve günlükler: `%ProgramData%\WindowsKioskLauncher`.
- Kiosk tarayıcı profili: varsayılan olarak `%LOCALAPPDATA%\WindowsKioskLauncher\ChromeProfile`. Ziyaret edilen sitenin oturumları ve çerezleri bu profilde bulunabilir.
- Kurulum, makine genelindeki `AllowEdgeSwipe` ilkesini `0` yapar; önceki değeri yedekler ve kaldırma sırasında geri yüklemeyi dener.
- Kaldırmak için **Kaldir.cmd** kullanın. Betik zamanlanmış görevi/kısayolları kaldırır, kiosk süreçlerini durdurur ve Program Files/ProgramData altındaki uygulama klasörlerini siler. Saklamak istediğiniz ayar ve günlükleri önceden yedekleyin.
- Kaldırıcı, LocalAppData altındaki Chrome profilini silmez. Oturum/çerez temizliği gerekiyorsa kiosk kapalıyken bu profili ayrıca temizleyin.

Kiosk görünümü tam bir Windows güvenlik sınırı değildir. Paket kılavuzu Ctrl+Alt+Delete ve bazı Windows araçları gibi kaçış yollarının ayrıca yönetilmesi gerektiğini belirtir. EXE dosyaları Authenticode imzası taşımaz. Kaynak kod olmadan tam güvenlik veya telemetri yokluğu garantisi verilmez.

### Sürüm ve doğrulama
Uygulama dosyalarının ürün sürümü **1.1.4**, bu genel dağıtımın etiketi **v1.1.4-public.1**'dir. Gönderilen paketteki özel varsayılan adres hem yapılandırmada hem ajan içindeki sabit metinde genel örnek adresle değiştirilmiştir; sürüm kaynağı yeniden derlenmemiştir.

İki PowerShell betiği sözdizimi kontrolünden geçti. İki uygulamanın toplam **897 gömülü dosyası** açılıp karşılaştırıldı: ajan derlemesindeki tek adres metni dışında gömülü dosya içerikleri korunmuştur. Bunlar statik kontrollerdir; Windows üzerinde kurulum veya kiosk çalışma testi yapılmamıştır. ZIP bütünlüğü ve SHA-256 özeti ayrıca doğrulanmıştır.

### Depo yapısı
```text
installer/       Kurulum ve kaldırma PowerShell betikleri
config.json      Genel örnek yapılandırma
Kur.cmd          Kurulum başlatıcısı
Kaldir.cmd       Kaldırma başlatıcısı
SHA256SUMS.txt   Dağıtım ZIP'inin SHA-256 özeti
```

Releases ZIP'i bunlara ek olarak `app/KioskAgent.exe` ve `app/KioskLauncher.exe` içerir. Yayınlayan: [sinanback](https://github.com/sinanback). Bu bağımsız proje Microsoft veya Google tarafından geliştirilmiş ya da onaylanmış değildir. Depoya ayrıca açık kaynak lisansı verilmemiştir; üçüncü taraf bileşenlerin hakları sahiplerine aittir.

---

<a id="english"></a>
## English

### About
Windows Kiosk Launcher is a Windows application package designed to open a configured website in Chrome kiosk mode. It targets reception screens, touch terminals and shared devices focused on a single web application.

This repository contains **installation/removal scripts and a sample configuration**. Executables are distributed in the **Releases** ZIP. The original C# application source is unavailable, so this is not a complete, rebuildable source repository.

### Capabilities
The supplied package guide describes fullscreen Chrome, restart after browser closure, an isolated browser profile, **Ctrl+5** to exit, touch-keyboard/taskbar options, and optional shortcut/touchpad restrictions. These runtime behaviors have not been tested live in this public distribution.

The inspected installer creates a logon task for the selected user with **Limited** privileges, adds desktop/Start menu shortcuts and preserves existing installed configuration.

### Download and setup
1. Download **WindowsKiosk-1.1.4-public.1.zip** from [Releases](https://github.com/sinanback/windows-kiosk-launcher/releases). GitHub's automatic **Source code** ZIP does not include executables.
2. Extract the package to a permanent directory and ensure Chrome is installed.
3. Set `Url` in `config.json` to your web application's HTTP/HTTPS address. The default `https://example.com/` is a placeholder.
4. Run **Kur.cmd**. Installation requests administrator access and changes program files and a machine-wide Windows policy.
5. Restart Windows for the edge-swipe policy to apply. The kiosk starts at user logon; the **Kiosk Baslat** shortcut also starts it.
6. Exit with **Ctrl+5**. After installation, edit `%ProgramData%\WindowsKioskLauncher\config.json`, then restart the kiosk session to apply changes.

Use a separate test account first. This is a **public preview** with a neutralized embedded default URL. Verify installation, exit and removal on a test device before production use. Updating the package does not overwrite an existing installed configuration.

### Configuration
The sample exposes the target URL, Chrome executable/profile paths, startup/restart delays, Explorer restoration, modern touch keyboard, key restrictions, touchpad gesture restrictions and extra Chrome arguments. See the field table above and [config.json](config.json).

### System changes, privacy and removal
The installer writes to `%ProgramFiles%\WindowsKioskLauncher` and `%ProgramData%\WindowsKioskLauncher`, registers a scheduled task and sets the machine-wide `AllowEdgeSwipe` policy to `0`. The previous policy value is backed up for restoration during removal.

Run **Kaldir.cmd** to remove the scheduled task, shortcuts and installed program/configuration/log directories. Back up any settings or logs you need first. The uninstaller **does not delete the LocalAppData Chrome profile**. That profile may retain website cookies and signed-in sessions; clean it separately after stopping the kiosk if required.

A kiosk interface is not a complete Windows security boundary. The supplied guide notes that Ctrl+Alt+Delete and other Windows escape paths require separate management. Executables are not Authenticode-signed. Without the application source, this publication does not guarantee complete security or the absence of telemetry.

### Version and validation
Executable product version: **1.1.4**. Public package tag: **v1.1.4-public.1**. A private default URL was replaced in both configuration and the agent's embedded string; the application was not rebuilt from source.

Both PowerShell scripts passed syntax checks. All **897 embedded files** across the two executables were extracted and compared: only the agent's default URL string changed. ZIP integrity and SHA-256 were checked. These are static checks; installation and live kiosk behavior were not tested.

The repository contains setup scripts and configuration; the release ZIP additionally contains `app/KioskAgent.exe` and `app/KioskLauncher.exe`. Verify the download against `SHA256SUMS.txt`.

Published by [sinanback](https://github.com/sinanback). This independent project is not developed or endorsed by Microsoft or Google. No additional open-source license is granted; third-party components remain subject to their owners' rights.
