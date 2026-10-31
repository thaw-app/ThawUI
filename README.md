# ThawUI

The SwiftUI controls and styles shared by [Thaw](https://github.com/thaw-app/Thaw) and [Floe](https://github.com/thaw-app/Floe).

Depends only on SwiftUI, Foundation, CoreGraphics, Combine, and
CompactSlider. It knows nothing about app state, the settings model, or the
menu bar, which is what keeps it usable from more than one app.

`ThawWindow` is not here on purpose. It takes Thaw's `AppState` and reads the
app's display name, so it stays in Thaw.

## Strings

ThawUI holds no user-facing strings. Apps supply all text as
`LocalizedStringResource` or `Text`, so it resolves in the app's own catalog.

A literal such as `ThawBadge("New")` looks in the main bundle. An app whose
catalog lives in another bundle names it on the resource:
`LocalizedStringResource("New", bundle: .atURL(Bundle.module.bundleURL))`.

## Licensing

GPL-3.0. See [LICENSE](LICENSE).
