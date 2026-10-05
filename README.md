<div align="right">
  <details>
    <summary>🌐</summary>
    <div>
      <div align="center">
        <a href="#">العربية</a>
        | <a href="#">Deutsch</a>
        | <a href="#">English</a>
        | <a href="#">Español</a>
        | <a href="#">Français</a>
        | <a href="#">हिन्दी</a>
        | <a href="#">Bahasa Indonesia</a>
        | <a href="#">Italiano</a>
        | <a href="#">日本語</a>
        | <a href="#">한국어</a>
        | <a href="#">Português</a>
        | <a href="#">Русский</a>
        | <a href="#">ไทย</a>
        | <a href="#">Türkçe</a>
        | <a href="#">Tiếng Việt</a>
        | <a href="#">简体中文</a>
      </div>
    </div>
  </details>
</div>

<p align="center">
   <img src="https://files.catbox.moe/mdn05t.png" alt="Dartotsu Banner" width="100%">
</p>

<p align="center">
   <img src="https://img.shields.io/badge/platforms-android_windows_linux-06599d?style=for-the-badge&labelColor=00ffff&color=0d1117"/>
   <a href="https://github.com/LucidSami/Dartotsu-fork/releases"><img src="https://img.shields.io/github/v/release/LucidSami/Dartotsu-fork?style=for-the-badge&logoColor=168b94&label=Latest%20Release&labelColor=00ffff&color=0d1117"></a>
   <img src="https://img.shields.io/badge/license-UPL-green?style=for-the-badge&labelColor=00ffff&color=0d1117"/>
   <img src="https://img.shields.io/badge/status-active-success?style=for-the-badge&labelColor=00ffff&color=0d1117"/>
</p>

# Dartotsu Fork

A modern, high-performance hybrid tracking client built in Flutter for **AniList**, **MyAnimeList (MAL)**, and **Simkl**.

This project is a dedicated **Dartotsu fork** built by consolidating architectural paradigms, extension engines, and UI innovations from leading open-source anime, manga, and novel tracking ecosystems:
- **[Dartotsu](https://github.com/aayush2622/Dartotsu)** — Core Flutter application framework and multi-service tracking foundation.
- **[Saikou](https://github.com/saikou-app/saikou)** — Intuitive design patterns, UI ergonomics, and anime catalog experiences.
- **[Dantotsu](https://git.rebelonion.dev/rebelonion/Dantotsu/)** — Feature-rich client mechanics and cross-service synchronization concepts.
- **[AnymeX](https://github.com/RyanYuuki/AnymeX)** — Media playback pipelining, modern UI aesthetics, and novel reading workflows.
- **[LNReader](https://github.com/LNReader/lnreader)** — Advanced light novel formatting, rendering engines, and pagination.
- **[CloudStream](https://github.com/recloudstream/cloudstream)** — Modular extension bridging protocols and extensible architecture.

---

> [!IMPORTANT]
> ### 🛡️ DMCA & Copyright Disclaimer: Tracking Client Only
> **Dartotsu Fork is strictly a personal library management and list-tracking tool.**
> 
> - **Zero Hosted Content**: This application and repository do **NOT** host, upload, scrape, stream, distribute, or store any copyrighted multimedia content (no anime video files, no manga scanlations, no novel text, no torrent files).
> - **Pure Tracking Frontend**: The app operates exclusively as a third-party frontend client interfacing with legitimate, public tracking databases ([AniList](https://anilist.co), [MyAnimeList](https://myanimelist.net), and [Simkl](https://simkl.com)) via their respective official APIs. It allows users to manage their watchlists, reading lists, scores, and episode counters.
> - **No DMCA Issues**: Because this software does not provide access to or host any protected media, it is fully compliant with copyright laws and the Digital Millennium Copyright Act (DMCA).
> - **User Responsibility & Third-Party Extensions**: Any external extensions or third-party add-ons are entirely decoupled and maintained by independent parties. Dartotsu Fork has no affiliation with or ownership of any third-party repositories. Users are individually responsible for their usage and compliance with applicable local laws and copyright regulations.

---

## ✨ Key Features & Improvements

- **Reliable Hybrid Multi-Provider Sync**:
  - Independent status handling: logged-in accounts (AniList, MAL, Simkl) track progress concurrently, while unauthenticated services are safely bypassed with zero errors.
  - Zero reliance on unofficial third-party scraping proxies (pure official APIs with zero Jikan dependency).
- **Instant Profile & Status Hydration**:
  - Offline-first cache ensures user profile pictures, usernames, and watch stats appear instantly upon login and startup without blank screens or infinite loading states.
- **Smooth Navigation & Aggressive Media Caching**:
  - Native gesture scrolling across media details, character guides, and episode lists.
  - Optimized caching pipelines for fluid playback and navigation.
- **Light Novel & Manga Reading**:
  - Integrated reader with customizable typography, dark/light themes, and automated chapter progression.
- **Multiplatform Architecture**:
  - Built for Android (ARM64), Windows Desktop, and Linux.

---

## 📥 Downloads

Pre-built binaries are available under **[GitHub Releases](https://github.com/LucidSami/Dartotsu-fork/releases)**:

| Platform | Package | Notes |
| :--- | :--- | :--- |
| **Android** | `Dartotsu-Android-arm64.apk` | Optimized for ARM64 mobile devices |
| **Windows** | `Dartotsu-Windows-x64.zip` | 64-bit Windows desktop portable bundle |
| **Linux** | `Dartotsu-Linux-x64.tar.gz` | 64-bit Linux desktop bundle |

---

## 🛠️ Building from Source

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.47.5 stable recommended)
- Java 17 JDK
- Android SDK with NDK

### Build Commands

```bash
# Clone the repository
git clone https://github.com/LucidSami/Dartotsu-fork.git
cd Dartotsu-fork

# Fetch dependencies
flutter pub get

# Build Android ARM64 Release APK
flutter build apk --release --target-platform android-arm64

# Build Desktop Releases
flutter build windows --release   # On Windows
flutter build linux --release     # On Linux
```

---

## 🤝 Acknowledgments & Credits

We extend our deep gratitude to the original authors and maintainers of the foundational open-source projects:
- **Dartotsu** by [aayush2622](https://github.com/aayush2622)
- **Saikou** by [saikou-app](https://github.com/saikou-app)
- **Dantotsu** by [rebelonion](https://git.rebelonion.dev/rebelonion)
- **AnymeX** by [RyanYuuki](https://github.com/RyanYuuki)
- **LNReader** by [LNReader](https://github.com/LNReader)
- **CloudStream** by [recloudstream](https://github.com/recloudstream)

## 📄 License
Dartotsu Fork is distributed under the Unabandon Public License (UPL). See [LICENSE.md](LICENSE.md) for full terms.
