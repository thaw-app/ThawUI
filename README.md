# ThawUI

The SwiftUI controls and styles shared by [Thaw](https://github.com/thaw-app/Thaw) and [Floe](https://github.com/thaw-app/Floe).

Depends only on SwiftUI, AppKit, Foundation, CoreGraphics, Combine, Carbon (for
key codes and the system's reserved shortcuts), and CompactSlider. It knows
nothing about app state, the settings model, or the menu bar, so more than one
app can use it.

`ThawWindow` stays in Thaw because it takes Thaw's `AppState` and reads the
app's display name.

## Strings

ThawUI holds no user-facing strings. Apps supply all text as
`LocalizedStringResource` or `Text`, so it resolves in the app's own catalog.

A literal such as `ThawBadge("New")` looks in the main bundle. An app whose
catalog lives in another bundle names it on the resource:
`LocalizedStringResource("New", bundle: .atURL(Bundle.module.bundleURL))`.

## Licensing

GPL-3.0. See [LICENSE](LICENSE). [LICENSE-EXCEPTION](LICENSE-EXCEPTION) adds a permission to link with PlatformRuntimeKit.
