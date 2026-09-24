---
name: iphone-duo
description: Use when building or adapting an iOS app for the iPhone Duo foldable — size-class layouts, vertical toolbars and overflow, hinge angle, reserved regions and layout arrangements, horizontal safe area, iOS 27 SDK compatibility, or Xcode 27.1 simulator testing.
---

# iPhone Duo Skill

Distilled from Bitrig's "I Watched Every iPhone Duo Developer Video. Here's What Matters."
(`https://youtube.com/watch?v=h00uDeTYdLA`, auto captions; full text in
`references/transcript.md`). Apple sources it summarizes:

- Design for iPhone Duo — `https://developer.apple.com/videos/play/tech-talks/111466/`
- Prepare Your App for iPhone Duo — `https://developer.apple.com/videos/play/tech-talks/111461/`
- Raise the Bar with iPhone Duo — `https://developer.apple.com/videos/play/tech-talks/111462/`
- Strike a Pose with Adaptive Layouts on iPhone Duo — `https://developer.apple.com/videos/play/tech-talks/111463/`
- Leverage multiple displays and scenes on iPhone Duo — `https://developer.apple.com/videos/play/tech-talks/111464`
- HIG: Designing for iPhone Duo — `https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo`
  (digest in `references/hig-designing-for-iphone-duo.md`)

Full English subtitle transcripts of all five Tech Talks are vendored under
`references/tech-talks/` — consult them for exact API names and demo details.

Core thesis: an app that *runs* on Duo is not an app *designed* for Duo.
A stretched iPhone UI on the unfolded display is the failure mode to avoid.

## 1. Size classes, not six UIs

Duo has six layout configurations, but support them through the familiar
compact/regular size classes, not per-device branches:

| State | Size class | Note |
|---|---|---|
| Closed portrait | compact width × regular height | classic iPhone |
| Closed landscape | compact × compact | NEW, must add |
| Unfolded | regular × regular | like iPad |

Rules:

- Read `horizontalSizeClass` / `verticalSizeClass` environment values, adapt.
  Example: vertical stack on compact → horizontal stack or `NavigationSplitView`
  on regular × regular; sidebar `TabView` for dense content.
- Full iPad support is the prerequisite: multitasking, resizability, multiple
  scenes/instances, landscape, Split View. If iPad is second-class, Duo is broken.
- No hardcoded view widths. Re-enable landscape if it was disabled.
- Payoff is 2-for-1: Duo readiness yields a genuinely good iPad app.

## 2. SDK, simulator, resizability skill

- Build with iOS 27 SDK or above. Older builds render letterboxed on black —
  visibly obsolete next to updated competitors.
- iPhone Duo Simulator ships in Xcode 27.1 (Apple: late September 2026).
- Xcode 27.1 adds an AI agent skill for resizability — use it alongside this skill.
  The vendored Apple `uikit-app-modernization` skill covers the UIKit half
  (scene lifecycle, `UIScreen.main` / orientation / symmetric-safe-area removal).

## 3. Toolbars and tabs go vertical

Toolbars/tab views flip between horizontal and vertical rails on the fly.

- Use native components only: `NavigationStack`, default `TabView`, toolbar API.
  Custom toolbars/tab bars inherit all this work manually — migrate to native.
- Vertical rail shares room with status bar and Live Activities: adopt the iOS 27
  toolbar overflow API (items collapse into a menu button).
- `toolbarVerticalCompressionBehavior`: which collapses first (tabs vs buttons).
- Visibility priority API: keep critical buttons out of the overflow menu.
- Order top-to-bottom: back button, prominent action, secondary actions.
- Text-only buttons stay in the horizontal bar (too wide). Prefer `Label`
  (title + icon): icon lands in the vertical rail, icon + text in overflow.
- Access behavior API: pin icon buttons to the horizontal bar when grouped with
  text buttons. Badge API for cart/inbox counts. No `ToolbarSpacer` in the
  vertical rail. `toolbarVerticalBehavior` API opts out (e.g. Calculator).
- Custom toolbar owners: read the toolbar-vertical-edge environment value.

## 4. Hinge

- Discrete state (open / closed / partially open) plus continuous live angle.
- `onHingeChange`-style modifier drives animations, reflections, instruments
  (video demo: content reflection by angle; guitar "whammy" pitch bend).
- Treat hinge input as a feature source, not just layout data.

## 5. Reserved regions, arrangements, safe area

- Fold (`.division`) plus inner/outer cameras (`.occlusion`) are reserved
  regions, active per pose. Never park content or controls on the fold; reflow
  centered content to one side, split evenly when half-folded.
- Native containers (`NavigationStack`, `SplitView`, `TabView`, `List`,
  `ScrollView`) avoid regions automatically — another reason to stay native.
- Manual path: `GeometryReader` exposes region frames + active flags.
- Custom views: `LayoutContainer` + `Arrangement` (`.split` / `.overlay`).
  Arrangement inputs: size class, aspect ratio, reserved regions. Outputs:
  show/hide plus frame. Prefer system arrangements.
- Honor the horizontal safe area (vertical-toolbar rail). Full-bleed
  backgrounds may ignore it; scrolling content must not slide under the rail.

## 6. Ship checklist

StandBy widgets (usage spikes on Duo — finish adoption), PencilKit research
(Pencil support lands later this year), concentric-rectangle API for the
asymmetric outer screen, pose-dependent sheets, drag and drop (side-by-side
multitasking makes it expected, even for former iPhone-only apps).
