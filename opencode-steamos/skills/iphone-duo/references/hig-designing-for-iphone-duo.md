# Designing for iPhone Duo — HIG digest

Source: `https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo`
(New page, September 9, 2026. Full page text used; navigation/footer stripped.)

> An app designed for iPhone Duo adapts seamlessly to both displays, providing
> a continuous experience as the device opens and closes.

Standard system components + a resizable design adapt to Duo poses with little
extra work. Still designing for iPhone: iOS patterns apply.

## Anatomy

- Inner + outer display. Outer used closed; toolbars/tab bars sit on the side
  to maximize vertical room. Controls stay on the side when open in landscape
  for continuity across displays.
- Center hinge supports many holds/positions; folding changes available space.
- Outer front camera: corner, always visible, vertically aligned with side
  controls. Inner camera: behind display, hidden until active.

## Device poses

Book-fold, flat on surface, standing on edges (six illustrated poses). Do not
design per pose — use size classes. Compact-width layout (outer) + regular-width
layout (inner) cover every pose. Expand existing layout; never reinvent on resize.

## Best practices

- Build to resize. Two displays × poses × Split View multitasking = many sizes.
  Size classes, layout margins, safe-area insets. No fixed widths, no
  display-specific dependencies.
- Consistent experience across displays. Same functionality and element state;
  keep information hierarchy; inner display may show one extra hierarchy level
  (Mail: list vs message when closed).
- Same controls/content in every pose. Controls may overflow, content may move
  or resize — access must not disappear. See Dynamic layouts, Vertical controls.
- Follow system vertical layout for toolbars/tab bars/navigation. Outer display
  is wider/shorter than other iPhones, so controls move aside; inner portrait
  keeps standard horizontal bars (enough vertical space).
- Games: playable in every pose. May lock portrait or landscape, but fill the
  screen as pose changes. Keep text/control sizes consistent; prefer aspect
  change over letter/pillarboxing.

## Dynamic layouts

Layout margins + safe-area insets; Apple Design Resources for metrics;
`GeometryProxy.safeAreaInsets` (SwiftUI), `UIView.safeAreaInsets` (UIKit).

## Reserved regions

Display areas content avoids or components accommodate (cf. iPad window controls):

- Outer front camera: always present; expands into Dynamic Island for Live
  Activities. System arranges side controls around it automatically.
- Inner front camera: present only while camera active; UI shifts aside to
  signal it.
- Folding region: conditional; when partially open it splits the inner display,
  excluding the center fold.

System components (alerts, context menus, sheets) move for the fold
automatically; split views adjust column width/margins to inner symmetry.
Custom components use reserved-region APIs.

Fold behavior: prefer auto-adapting containers (Notes split view adjusts pane
widths). Grids: even column counts divide cleanly. Move only what is needed —
small adjustments, no dramatic rearrangement.

Split views: expand on inner, collapse to one pane on outer (regular/compact
adaptation). Standard components handle reserved regions automatically.
(`NavigationSplitView`, `UISplitViewController`.)

## Arrangement views

Layout container holding primary + secondary view, organized by display size,
orientation, reserved regions. Keep navigation (split views, tab views) outside
them — they lay out content only.

- Split: divides area; horizontal split when wider than tall, vertical when
  taller. Axis can be limited.
- Overlay: layers views; when partially folded each side gets one view,
  otherwise primary sits atop secondary. Secondary collapsible.

Rule of thumb: side-by-side or stacked (`HStack`/`VStack`) → split; layered
(`ZStack`) → overlay.

## Vertical controls

Side rail holds, top to bottom: Dynamic Island, status bar, toolbar (incl.
navigation buttons), tab bar. In Split View each app uses its outer edge (left
app: controls left). Rail stays hardware-aligned: same spot vs camera on outer,
same side in RTL.

- Asymmetry: content area is lopsided — safe-area everything, incl. opposite
  edge (Split View neighbor's rail).
- Consistency: not every pose is vertical; keep relative control positions
  stable across poses.
- Order: Back/Close top, then prominent actions (Done), then groups in original
  order with system spacing.
- Overflow runs bottom-to-top by default. Visibility priority per group, then
  per item: `toolbarItemVisibilityPriority` (SwiftUI),
  `UIBarButtonItemVisibilityPriority` (UIKit). Preserve frequent actions
  (Compose, New Note) and badged/status items longest.
- Default compression: navigation-focused views collapse toolbar into overflow
  (tab bar stays); task-focused views minimize tab bar (toolbar stays).
- Do not override default bar placement — it is a core Duo pattern.
- Full-width exceptions: bar-less immersive non-scrolling layouts may span all
  (Calculator: 4×5 buttons on iPhone 16 → 5×4 on Duo outer), unless clashing
  with Dynamic Island/statusbar. Hybrid allowed.
- Groups (`ToolbarItemGroup` / `UIBarButtonItemGroup`) space + adapt
  automatically — never hand-space. System overflow menu absorbs custom
  overflow menus; reserve ellipsis glyph for overflow only.
- Controls belonging to a non-trailing pane stay with that pane (Mail list
  controls above leading pane).
- Every non-text-only item gets title + symbol (`Label` / `UIBarButtonItem`):
  system picks representation; title feeds overflow menus. Text buttons stay
  horizontal — minimize them, prefer symbols.

## Resources / videos

- Apple Design Resources: `https://developer.apple.com/design/resources`
- Tech Talks: Design (111466), Prepare Your App (111461), Raise the Bar
  (111462), Strike a Pose (111463), multiple displays and scenes (111464).
  Transcripts vendored under `references/tech-talks/`.
