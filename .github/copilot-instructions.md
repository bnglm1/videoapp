# Copilot Instructions for videoapp

## Project Overview
- **videoapp** is a multi-platform Flutter application for video streaming, supporting multiple video sources per episode, dynamic source selection, and platform-specific playback.
- The app uses a modular structure: `lib/models` (data models), `lib/screens` (UI/pages), `lib/services` (API, video, and data logic), and platform folders (`android/`, `ios/`, etc.).
- Video data is loaded from a remote JSON (GitHub raw), parsed into `Series`, `Season`, and `Episode` models. Each episode can have multiple video sources (`videoSources`).

## Key Patterns & Conventions
- **Episode Navigation:** Always pass the full episode map (`episode.toNavigationMap()`) to detail screens to ensure all video sources are available for selection.
- **Video Source Selection:**
  - Use `_buildVideoSourceSelector()` in `episode_detail_screen.dart` to show an expandable card for source selection if multiple sources exist.
  - The selected source's `url` is used for playback. Always check that `videoSources` is non-empty and all `url` fields are valid.
- **Player Selection Rule:**
  - `.mp4` URLs use `video_player`.
  - All other URLs use `webview_flutter`.
  - No JavaScript injection is allowed in the player logic.
- **Error Handling:**
  - If no valid video URL is found, show a user-friendly error ("Videoya ait link bulunamadı").
  - Always check both `videoUrl` and `videoSources` before navigation or playback.
- **Data Flow:**
  - Data is fetched via `GitHubService` (`lib/models/github_service.dart`).
  - All navigation and playback logic expects episode data to include `videoSources` for multi-source support.

## Developer Workflows
- **Build/Run:** Use `flutter run` for development. No custom build scripts.
- **Testing:** No explicit test suite found; add widget tests in `test/` as needed.
- **Debugging:** Use print statements for runtime debugging. Check for null/empty `videoSources` and invalid URLs.

## Integration Points
- **External Data:** Video/series data is loaded from a GitHub raw JSON URL (see `GitHubService`).
- **Video Playback:** Uses `video_player` and `webview_flutter` packages. Platform-specific configs may be required for permissions.

## Examples
- See `lib/screens/season_list_page.dart` for correct episode navigation and data passing.
- See `lib/screens/episode_detail_screen.dart` for source selection and playback logic.
- See `lib/models/video_model.dart` for data model structure and serialization.

## Project-Specific Advice
- Always validate `videoSources` before attempting playback.
- When adding new episode data, ensure every source has a valid `url`.
- Keep UI logic for source selection and error handling consistent with existing patterns.

---

If any section is unclear or incomplete, please provide feedback for further refinement.
