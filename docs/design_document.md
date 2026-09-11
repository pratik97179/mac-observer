# Everythinginator — Complete Visual & Interaction Design Specification

## 0. Purpose

This document is the authoritative UI/UX implementation specification for Everythinginator.

Everythinginator is a native macOS observability application for Apple Silicon Macs. It exposes system performance, processes, storage, networking, connectivity, power, thermal state, system events, location, security/capabilities, and other available system telemetry through a single coherent interface.

The application must feel modern, premium, native to macOS, minimal without being empty, information-dense without being cluttered, tactile rather than flat, visually responsive during activity, and consistent across every screen.

The design must communicate hierarchy through depth, material, spacing, typography, shape, proportional visualization, motion, state, and progressive disclosure.

---

# 1. Non-negotiable design rules

## Rule 1 — Never represent every metric as a number + graph

Choose the visualization according to the semantic meaning of the data.

```text
Current magnitude      → number + bar
Capacity               → number + capacity bar
State                  → status dot/glyph
Direction              → directional flow
Relative comparison    → proportional bar
Distribution           → segmented bar
Short trend            → sparkline
Detailed history       → interactive graph
Activity               → pulse/glow
Event                  → timeline marker
Relationship           → connected/linked visualization
Identity               → structured metadata
Unavailable data       → semantic unavailable state
```

## Rule 2 — Overview is not a data dump

Overview must answer:

1. Is the machine healthy?
2. What is currently consuming resources?
3. What is currently active?
4. Has something changed recently?
5. Where should I investigate?

Do not show low-value telemetry just because it is available.

## Rule 3 — Do not scatter widgets across empty space

Every visual element belongs to a clearly defined composition.

Use four Overview zones:

```text
1. Machine identity / health
2. Primary resource instrument
3. System activity timeline
4. Current activity
```

## Rule 4 — Surfaces must have depth

Primary surfaces must not look painted onto the background.

Use translucent materials, subtle tint, edge highlights, soft shadows, recessed surfaces, raised surfaces, and pressed states.

## Rule 5 — Motion communicates state

Animations must communicate appearing, changing, becoming active/inactive, selection, pressing, timeline movement, or depth. Do not animate content merely for decoration.

---

# 2. Design system architecture

Create:

```text
Theme
 ├── ColorTokens
 ├── TypographyTokens
 ├── SpacingTokens
 ├── RadiusTokens
 ├── ShadowTokens
 ├── MaterialTokens
 ├── MotionTokens
 └── ChartTokens

Components
 ├── Surface
 ├── Metric
 ├── Visualization
 ├── Navigation
 ├── Status
 ├── Timeline
 ├── Process
 ├── Network
 └── EmptyState

Screens
 ├── Overview
 ├── Performance
 ├── Network
 ├── Processes
 ├── Storage
 ├── Power
 ├── Events
 ├── System
 └── Settings
```

Do not hard-code visual values inside screen-specific views.

---

# 3. Coordinate and spacing system

Use an 8 px base grid.

```text
4 px      micro separation
6 px      icon/text adjustment
8 px      compact spacing
12 px     control padding
16 px     standard separation
20 px     component separation
24 px     surface padding
28 px     section padding
32 px     large separation
40 px     major section separation
48 px     visual breathing room
64 px     hero separation
```

Do not use arbitrary spacing such as 17, 23, 27, 35 px except for typography baseline alignment and icon geometry.

---

# 4. Window geometry

```text
Default:       1280 × 820
Minimum:       1050 × 700
Recommended:   1440 × 900
```

Content insets:

```text
Main content left:      44 px
Main content right:     44 px
Top content:            32 px
Bottom content:         40 px
```

Sidebar:

```text
Width:                  240 px
Internal horizontal:    16 px
Top content offset:     52 px
```

Reflow at narrower supported widths rather than introducing horizontal scrolling.

---

# 5. Color system

All colors must be centralized.

## 5.1 Base colors

```text
Canvas                 #0B0C10
CanvasRaised           #0F1116

SurfaceResting         #14161C
SurfaceElevated        #191C23
SurfaceFloating        #1E2129
SurfaceRecessed        #0F1116
```

## 5.2 Text

```text
Primary                #F2F3F7
Secondary              #A6A8B0
Tertiary               #70737C
Disabled               #4E5159
```

## 5.3 Accent

```text
Accent                 #8B8CFF
AccentBright           #A5A6FF
AccentMuted            #6667B8
```

Use a restrained blue-violet. Do not assign separate permanent colors to CPU, Memory, GPU, Network, Disk.

## 5.4 Semantic colors

```text
Healthy                #69C58C
Warning                #E2AE61
Critical               #E36D73
Unavailable            #676A73
```

## 5.5 Opacity hierarchy

```text
Surface tint            4–7%
Edge highlight          4–8%
Divider                 5–8%
Hover                   +3–5%
Pressed                 -3–5%
Disabled content        40–55%
Secondary text          65–75%
```

---

# 6. Gradient system

Use gradients only for:

- chart area fills
- subtle accent glow
- background atmosphere
- selected/focused state

Chart fill:

```text
Top:       Accent 12–16%
Middle:    Accent 5–8%
Bottom:    Accent 0–2%
```

Background atmosphere uses one extremely low-opacity radial gradient behind main content. Do not create visible colored blobs.

---

# 7. Material system

## Level 0 — Canvas

```text
Fill: Canvas
Shadow: none
Border: none
```

## Level 1 — Recessed

Use for timelines, graph canvases, input wells, and compact controls.

```text
Fill: CanvasRaised
Outer shadow: none
Inner shadow: black 12%
Top highlight: white 3%
Radius: 14–18 px
```

The surface must visually appear depressed into its parent.

## Level 2 — Resting

Use for process activity and secondary information.

```text
Material: thin material or equivalent
Tint: SurfaceResting
Outer shadow: black 18–22%
Blur: 22–26 px
Y: 6–8 px
Top highlight: white 4–5%
Radius: 16–20 px
```

## Level 3 — Elevated

Use for the Primary Resource Instrument and major interactive sections.

```text
Material: regular material or equivalent
Tint: SurfaceElevated
Outer shadow: black 26–32%
Blur: 28–34 px
Y: 9–12 px
Top highlight: white 6–7%
Radius: 20 px
```

## Level 4 — Floating

Use for popovers, tooltips, inspectors, and context menus.

```text
Material: regular material
Tint: SurfaceFloating
Outer shadow: black 32–40%
Blur: 36–48 px
Y: 12–18 px
Top highlight: white 7–8%
Radius: 14–18 px
```

Do not apply Level 3/4 shadows to every component.

---

# 8. Surface depth behavior

Every interactive surface requires:

## Resting

Normal material, shadow, and highlight.

## Hover

```text
Brightness +4%
Shadow +10%
Highlight +1%
Duration 160 ms
```

## Pressed

```text
Brightness -4%
Shadow -50%
Inner shadow +10%
Translation Y +1 px
Duration 100 ms
```

## Selected

```text
Accent tint 8–12%
Accent edge highlight 5%
Shadow slightly increased
```

Do not use scale-based button animations larger than 1–2%.

---

# 9. Corner geometry

```text
Window major surface       22 px
Primary surface            20 px
Secondary surface          16 px
Control                    12 px
Compact control             9 px
Pill                       999 px
```

---

# 10. Typography

Use the system font.

```text
HeroTitle           32 pt / semibold
PageTitle           26 pt / semibold
HeroMetric          42 pt / semibold
LargeMetric         28 pt / medium
SectionTitle        15 pt / semibold
Body                14 pt / regular
Secondary           13 pt / regular
Metadata            11 pt / medium
Micro               10 pt / medium
```

Use tabular numerals / `.monospacedDigit()` for CPU percentages, memory amounts, throughput, timestamps, and latency.

---

# 11. Icon system

Use SF Symbols.

```text
Sidebar                 18 px
Navigation secondary    16 px
Inline metric           14–16 px
Toolbar                 18 px
Hero action             20 px
```

Use consistent symbol weight. Do not use colorful custom icons for primary navigation.

---

# 12. Visualization language

## Level 1 — Recognition

Use number, dot, or compact glyph.

## Level 2 — Magnitude

Use bar, progress, or segmented bar.

## Level 3 — Trend

Use sparkline or pulse.

## Level 4 — Analysis

Use detailed interactive graph, timeline, or cross-domain correlation.

Use Level 4 only on detail screens or explicit investigation views.

---

# 13. Metric component

Create:

```swift
MetricBlock
```

Structure:

```text
Label
Hero value
Primary visualization
Secondary interpretation
```

Example:

```text
CPU

21%

███████░░░░░░

P-core 46% · E-core 18%
```

Spacing:

```text
Label → value:              8 px
Value → visualization:      10 px
Visualization → metadata:   8 px
```

---

# 14. Bar visualization

Use for CPU utilization, memory capacity, disk capacity, battery, relative process consumption, and link utilization.

```text
Height:      6–8 px
Radius:      999 px
Background:  white 7–10%
Fill:        Accent
```

The bar must not visually overpower the number.

---

# 15. Segmented bar

Use for P/E core distribution, storage categories, connection states, and memory composition.

```text
Segment gap: 2–4 px
```

Use related tonal variants rather than unrelated colors.

---

# 16. Sparkline

Use for short-term history.

```text
Height:       32–44 px
Stroke:       1.5–2 px
Fill:         accent 2–12%
```

No permanent axis, grid, legend, or labels. Use smooth interpolation. The live edge may contain a small indicator.

---

# 17. Pulse

Use for system activity, event intensity, network activity, and live activity indicators.

```text
Height:       30–40 px
Width:        220–280 px
Stroke:       single accent line
Fill:         subtle area
```

No axes or labels.

---

# 18. Directional flow visualization

Use for network upload/download, disk read/write, and transfer rates.

Example:

```text
↓ 18.4 MB/s
━━━━━━━╸━━━━
```

The moving segment travels toward the arrow.

```text
idle   → no motion
low    → slow
medium → moderate
high   → fast
```

Never animate faster than 2 cycles/sec.

---

# 19. Status visualization

```text
● Nominal
● Elevated
● Critical
```

Dot size:

```text
6–8 px
```

Use a 2–4 px low-opacity glow for active states.

Do not animate normal states continuously.

Critical state breathing animation:

```text
1.2–1.6 sec cycle
```

---

# 20. Empty-state system

Empty states must preserve the visual structure of the component.

Never replace a missing visualization with a bare `N/A`, `No data`, or `—`.

## Empty bar

```text
CPU
—

░░░░░░░░░░░░░░

Waiting for telemetry
```

Use a neutral recessed track with a short dashed center marker.

## Empty sparkline

```text
················
Collecting history…
```

Do not draw a fake flat line.

## Empty timeline

```text
SYSTEM ACTIVITY

┌─────────────────────────────────────────┐
│                                         │
│      Collecting system history…         │
│                                         │
└─────────────────────────────────────────┘
```

Use a low-contrast scanning line.

## Unavailable telemetry

```text
GPU
—

Telemetry unavailable

View Capabilities →
```

Do not show `0%`.

## No processes

```text
CURRENT ACTIVITY

No notable activity

The system is currently quiet.
```

## No network connections

```text
CONNECTIONS

No active connections

Network is connected, but no observable
connections are currently active.
```

## Permission required

```text
LOCATION

Location access required

Enable Location Services to view
device location.

Enable in System Settings →
```

## History unavailable

```text
HISTORY

Collecting data

Historical analysis becomes available
after enough telemetry has been recorded.
```

---

# 21. Loading states

Do not use a generic whole-page spinner.

Use skeleton geometry matching the final component.

Metric:

```text
CPU
████

░░░░░░░░
```

Graph:

```text
soft placeholder baseline
+
animated scanning highlight
```

Crossfade skeleton → content over 220 ms.

---

# 22. Error states

Distinguish:

```text
Unavailable
Permission required
Collector error
Temporarily stale
Unsupported
```

### Permission required

```text
Network inspection

Permission required

Enable Network Extension access
to inspect application traffic.

Open Capabilities →
```

### Collector error

```text
CPU telemetry

Collector unavailable

Last valid sample
02:41:18

Retry collector
```

### Stale

```text
Memory

10.2 GB

Updated 14s ago
```

Use a muted stale indicator, not red.

---

# 23. Data freshness

Live:

```text
● Live · 0s ago
```

Guidance:

```text
5–15 sec  → muted freshness indicator
15–60 sec → visibly stale
>60 sec   → stale state
```

Never label stale data as live.

---

# 24. Overview composition

The Overview contains exactly four visual zones:

```text
ZONE 1 — Machine identity / health
ZONE 2 — Primary Resource Instrument
ZONE 3 — System Activity Timeline
ZONE 4 — Current Activity
```

## Zone 1

```text
MacBook Air
Apple Silicon · 16 GB · macOS 27

● Healthy
```

Compact utility controls on right:

```text
Pulse
Live
Search
```

Do not use a giant alert panel for health.

## Zone 2

Create ONE Level 3 elevated surface.

Inside:

```text
CPU                 MEMORY                 GPU

21%                 10.2 GB                18%

███████░░░░░        ██████████░░           █████░░░░

sparkline           sparkline              sparkline

P-core 46%          Pressure normal        4.1 GB
E-core 18%          Swap 0 GB              GPU memory
```

The three metrics share the same surface, baseline, internal padding, and column alignment.

Recommended internal padding:

```text
24 px top/bottom
28 px left/right
24–32 px column gaps
```

Do not put a bordered card around each metric.

## Zone 3

Use ONE Level 1 recessed surface.

Separate traces sharing the same time axis:

```text
CPU      ─────╮──────╭────────
MEMORY      ╭─╯──────╯────────
NETWORK  ───────╮─────────────
DISK           ╰────╮────────

          10:42   10:43
```

No normalized blend of unrelated metrics.

## Zone 4

Use ONE Level 2 resting surface.

Example:

```text
Chrome                          14%
██████████░░░░░
2.1 GB RAM · ↓ 1.8 MB/s

Docker                           8%
██████░░░░░░░░░
1.4 GB RAM · ↓ 0.4 MB/s
```

Do not make the default view a dense spreadsheet.

---

# 25. Overview spacing

Use:

```text
Machine header
↓ 28 px
Primary resource surface
↓ 28 px
Timeline surface
↓ 28 px
Activity surface
```

No unexplained large vertical gaps.

---

# 26. Overview alignment

CPU, Memory, GPU columns must share:

```text
label baseline
hero-value baseline
visualization baseline
metadata baseline
```

Do not permit vertically misaligned metrics.

---

# 27. Timeline interaction

Hover anywhere on the timeline creates one shared crosshair.

```text
           │
CPU      ──●────────
MEMORY     ●───────
NETWORK  ──●───────
DISK       ●───────
           │
        10:42:18

CPU       28%
Memory    10.1 GB
Network   4.8 MB/s
Disk      12 MB/s
```

Drag to select a time interval.

Selection summary:

```text
SELECTED INTERVAL

02:41:12 – 02:41:47
35 seconds

CPU peak        94%
Memory peak     21.4 GB
Network peak    34 MB/s
Disk peak       182 MB/s

Events          14

View analysis →
```

---

# 28. Current activity behavior

Default sort:

```text
CPU descending
```

Allow:

```text
CPU
Memory
Disk
Network
```

Hover reveals:

```text
CPU
Memory
Disk
Network
PID
```

Click opens Process Detail.

---

# 29. Sidebar

Width:

```text
240 px
```

Navigation:

```text
Overview

Performance
Network
Processes
Storage
Power
Events

System
Capabilities
Settings
```

Secondary navigation:

```text
Performance:
CPU
GPU
Memory

Network:
Overview
Connections
DNS
Wi-Fi
Internet
IP
Routes
```

Do not exceed two nesting levels.

Item geometry:

```text
Height:              36 px
Radius:              10 px
Horizontal padding:  10 px
Icon/text gap:       10 px
```

Selected:

```text
accent 10% fill
white 5% highlight
soft shadow
accent icon
primary text
```

Hover:

```text
white 4% fill
```

Pressed:

```text
darkened fill
inner shadow
```

---

# 30. Top bar

Structure:

```text
[Machine]                      [Pulse] [Live] [Search]
```

Search:

```text
40 × 40 px
12 px radius
floating surface
SF Symbol magnifyingglass
⌘K
```

Pulse is an ambient system indicator, not another chart.

---

# 31. Performance views

## CPU

Overview uses:

```text
number + utilization bar + sparkline
```

Detail uses:

```text
large interactive history
P-core distribution
E-core distribution
load average
thread count
process contributors
```

Per-core view uses bars:

```text
P1  ███████████░░
P2  ███████░░░░░
P3  █████░░░░░░░
```

Do not render one large chart per core.

## GPU

Use:

```text
utilization
GPU activity
GPU memory
process contributors
```

Use one detailed graph plus bars. Never invent unavailable metrics.

## Memory

Primary representation is capacity:

```text
10.2 / 16 GB

██████████░░░░

Pressure       Normal
Compressed     1.2 GB
Wired          3.1 GB
Cached         4.7 GB
Swap           0 GB
```

Then history.

## Storage

Capacity:

```text
381 GB / 1 TB

██████████░░░░
```

Throughput:

```text
READ
↓ 142 MB/s
━━━━━━╸━━━━━━

WRITE
↑ 31 MB/s
━━╸━━━━━━━━━
```

Use segmented bars for filesystem/category breakdowns. Do not use pie charts.

## Power

Battery:

```text
79%
████████████░░░░
```

Power draw:

```text
14.2 W
╱────╲
```

Charging uses a state indicator.

## Thermal

Thermal is primarily a state:

```text
● Nominal
```

Elevated:

```text
● Elevated

System thermal pressure is elevated.
```

Do not use a decorative thermometer gauge.

---

# 32. Network views

## Network Overview

```text
NETWORK

Connected

↓ 18.4 MB/s
━━━━━━━╸━━━━

↑ 2.1 MB/s
━━╸━━━━━━━━

Latency 18 ms
Packet loss 0.0%
```

Drill-down controls:

```text
Connections
DNS
Wi-Fi
Interfaces
Internet
IP
Routes
```

## Connections

Group by process:

```text
Chrome

● google.com:443
  1.8 MB ↓

● github.com:443
  120 KB ↓

Docker

● registry...:443
  4.2 MB ↓
```

Selecting a connection reveals:

```text
Process
Destination
Resolved IP
Local endpoint
Remote endpoint
Protocol
State
Bytes
First seen
Last activity
DNS information
```

## DNS

Chronological activity:

```text
04:42:11
Chrome → github.com
104.x.x.x
12 ms

04:42:14
Docker → registry.npmjs.org
104.x.x.x
18 ms
```

Latency comparison may use compact bars:

```text
12 ms   ━━━
18 ms   ━━━━━
43 ms   ━━━━━━━━━━━
```

## Wi-Fi

Use:

```text
SSID
connection status
signal
channel
link speed
IPv4
IPv6
gateway
DNS
```

Signal:

```text
███████████░░░
-48 dBm
```

Do not use a circular gauge.

## Internet / IP

Use compact grouped fields:

```text
Public IP
ISP
ASN
DNS
Gateway
Latency
Packet loss
```

Keep device IP and public IP distinct.

---

# 33. Processes

Default sorting:

```text
CPU descending
```

Rows:

```text
Application
resource bar
primary number
secondary resource
```

Example:

```text
Chrome                          14%
██████████░░░░░
2.1 GB RAM · ↓ 1.8 MB/s
```

Use indentation only for real parent-child process relationships.

Example:

```text
Docker
  docker-engine
    node
    postgres
```

---

# 34. Events

Vertical timeline:

```text
04:42:11   NETWORK
Chrome → github.com

04:42:13   PROCESS
Docker launched

04:42:15   MEMORY
Pressure changed → elevated

04:42:17   STORAGE
Docker wrote 182 MB
```

Each event includes:

```text
timestamp
domain
event type
entity
concise description
```

When many events occur in a short interval:

```text
04:42:11–04:42:16

12 network events
8 DNS queries
3 connections opened

Expand →
```

Do not render hundreds of individual rows by default.

---

# 35. Capabilities

Use a dedicated capabilities/permissions screen.

Example:

```text
CAPABILITIES

System monitoring          ● Enabled
Network inspection         ● Permission required
DNS inspection             ● Enabled
Location                   ● Disabled
Endpoint monitoring        ● Available
```

Selecting one displays:

```text
What it provides
Why permission is required
Current status
How to enable it
```

Relevant empty-state actions link here.

---

# 36. Location

Keep device location and IP-derived location separate.

```text
LOCATION SERVICES

● Authorized

Approximate location
City, Region

Coordinates
xx.xxxxxx, xx.xxxxxx

Accuracy
±xx m

Source
Core Location
```

Do not show location on Overview by default.

---

# 37. Universal search

`⌘K` opens a Level 4 floating surface.

Target:

```text
Width: 620 px
Radius: 18 px
```

Search across:

```text
metrics
processes
connections
DNS
events
interfaces
system entities
settings/capabilities
```

Result row:

```text
icon
name
type
secondary description
```

---

# 38. Process and entity transitions

Clicking an entity preserves context.

Examples:

```text
CPU process contributor → Process Detail
Network destination → Connection Detail
Event → Related Entity
Timeline interval → Analysis
```

Use transitions that visually connect source and destination.

---

# 39. Session analysis

A recorded session contains:

```text
Start
End
Duration
System timeline
Anomaly markers
Events
Cross-domain metrics
```

Header:

```text
SESSION

14:32:10 → 14:47:42
15m 32s
```

Clicking an anomaly marker opens an event window:

```text
CPU increased 42% → 91%
Memory increased 10.8 → 18.9 GB
Docker network activity increased
```

---

# 40. Anomaly treatment

Use:

```text
small semantic marker
+
short contextual explanation
```

Examples:

```text
↑ Memory pressure elevated
↑ Network throughput spike
↑ CPU saturation
```

Do not create giant red alert panels unless immediate user action is required.

---

# 41. Animation system

Centralize:

```text
Micro interaction      100 ms
Hover                  160 ms
Tooltip                180 ms
State transition       200 ms
Content crossfade      220 ms
Surface transition     240 ms
Navigation             280 ms
Large layout change    320 ms
```

Use `easeOut` or `easeInOut`.

Use spring animation only for controls that benefit from a physical response.

Do not use bouncy navigation.

---

# 42. Live data animation

Do not animate telemetry numbers by counting every intermediate value.

Update values directly.

For visual continuity:

- bars interpolate
- graph paths extend
- flow indicators move
- status changes crossfade

Number changes use short opacity/position interpolation if needed.

---

# 43. Performance requirements

Telemetry rendering must not become a telemetry workload.

Requirements:

- centralize sampling
- batch UI updates
- avoid one timer per view
- use `Canvas` for high-frequency graphs
- keep bounded live buffers
- decouple collection frequency from render frequency
- avoid redrawing unrelated views
- stop high-frequency rendering for hidden screens
- downsample historical data before plotting large ranges

Target:

```text
Overview:          5–10 visual updates/sec
Interactive graph: up to 30 visual updates/sec
Telemetry sampling: independent of UI refresh
```

---

# 44. Responsive layout

At width >= 1200:

```text
CPU | Memory | GPU
Timeline full width
Activity full width
```

At width 1050–1199:

```text
CPU | Memory
GPU | supporting metrics
```

Reflow instead of shrinking typography below its minimum.

---

# 45. Accessibility

Support:

- Dynamic Type where appropriate
- keyboard navigation
- visible focus rings
- reduced motion
- sufficient text contrast
- VoiceOver labels
- non-color state communication

With Reduced Motion enabled:

```text
animated flow    → static directional bar
animated pulse   → static trace
crossfade        → instant state swap
elevation motion → static elevated state
```

Do not remove state information.

---

# 46. Light mode

Dark mode is primary.

Light mode must preserve depth hierarchy rather than simply invert dark colors.

Suggested starting colors:

```text
Canvas         #F4F5F7
Text           #17181C
Secondary      #62646B
```

Use white surfaces with low-opacity tint and low-opacity black shadows.

Implement light mode after dark mode is complete.

---

# 47. Visual QA

Test at:

```text
1050 × 700
1280 × 820
1440 × 900
```

Test:

```text
no data
low activity
normal activity
high activity
missing permission
collector failure
stale data
critical state
long process names
many processes
high event density
```

The UI must remain coherent in every state.

---

# 48. Reusable component inventory

```text
GlassSurface
InsetSurface
FloatingSurface

MetricBlock
MetricBar
CapacityBar
SegmentedBar
Sparkline
Pulse
FlowIndicator
StatusIndicator

ProcessRow
ProcessGroup
EventRow
EventGroup

SidebarItem
SectionHeader
ToolbarControl
SearchField
Tooltip
InspectorPanel

EmptyState
LoadingState
StaleState
UnavailableState
PermissionState

Timeline
TimelineTrace
TimelineCrosshair
TimelineRangeSelector
AnomalyMarker
```

---

# 49. Implementation roadmap

## Phase 1 — Foundation

Implement:

```text
Theme
Typography
Spacing
Material
Surface depth
Buttons
Status indicators
Bars
Sparklines
Flow indicators
Empty/loading/error states
```

Create an internal design-system preview screen containing every visual state.

Do not implement telemetry screens until the surface system looks correct.

## Phase 2 — Application shell

Implement:

```text
Window
Sidebar
Top bar
Search
Navigation
System Pulse
```

Validate all supported window sizes.

## Phase 3 — Overview

Replace the existing Overview completely.

Implement:

```text
Machine header
Primary Resource Instrument
CPU
Memory
GPU
Recessed System Timeline
Current Activity
```

Do not reuse the existing standalone-card layout.

## Phase 4 — Interaction

Implement:

```text
Hover
Pressed
Selected
Timeline crosshair
Timeline range selection
Process selection
Search
Keyboard navigation
```

## Phase 5 — Performance

Implement:

```text
CPU
GPU
Memory
Power
Thermal
```

## Phase 6 — Network

Implement:

```text
Network Overview
Connections
DNS
Wi-Fi
Interfaces
Internet
IP
Routes
```

Respect macOS permission/system-extension boundaries.

## Phase 7 — Processes / Storage / Events

Implement:

```text
Processes
Storage
Events
```

Use grouped progressive information instead of dense default tables.

## Phase 8 — System / Privacy

Implement:

```text
Capabilities
Location
Displays
Bluetooth
USB/Thunderbolt
Audio
Camera/Microphone
Security
System
```

## Phase 9 — Sessions

Implement:

```text
record
pause
stop
historical playback
time-range selection
event correlation
anomalies
```

## Phase 10 — Polish

Perform:

```text
spacing
typography
surface/depth
animation
empty states
accessibility
reduced motion
performance
consistency
```

Do not add new product features during this phase.

---

# 50. Acceptance criteria

The Overview is complete only when:

```text
[ ] CPU, Memory and GPU belong to one elevated resource instrument.
[ ] No random standalone graphs are scattered across the page.
[ ] No normalized blend of unrelated metrics exists.
[ ] Timeline is visibly recessed.
[ ] Activity is visibly elevated above the canvas.
[ ] Primary surfaces have material depth.
[ ] Interactive controls have raised and depressed states.
[ ] Visualization type matches data semantics.
[ ] Bars, sparklines, flow indicators and status states are used.
[ ] Graphs are reserved for temporal analysis.
[ ] Empty states preserve component geometry.
[ ] Missing telemetry is never represented as zero.
[ ] Loading states match final component geometry.
[ ] Stale data is visibly distinguished from live data.
[ ] Permission failures explain the required action.
[ ] Hover adds information without moving layout.
[ ] Navigation preserves spatial context.
[ ] Reduced Motion is supported.
[ ] The interface does not resemble a generic analytics dashboard.
[ ] The Overview remains coherent with no telemetry, low activity, and high activity.
```

---

# 51. Final design rule

Everythinginator should not ask:

> "What widget should display this metric?"

It should ask:

> "What visual form naturally communicates this data?"

Use:

```text
Number       → precision
Bar          → magnitude
Capacity bar → remaining headroom
Dot          → state
Glow         → activity/attention
Segment      → distribution
Flow         → directional throughput
Sparkline    → short trend
Full graph   → detailed history
Pulse        → event/activity
Timeline     → correlation
Motion       → change
Depth        → hierarchy
```

The application should behave as one coherent macOS observability instrument whose visual language changes according to the information being communicated.

---

# 52. Cursor instruction

Before modifying a screen:

1. Read this document.
2. Identify the screen's information hierarchy.
3. Map each metric to the correct visualization form.
4. Select the correct surface depth.
5. Reuse the design-system components.
6. Implement loading, live, stale, unavailable, permission, and error states.
7. Validate spacing against the 8 px grid.
8. Validate hover, pressed, selected, and reduced-motion states.
9. Test the screen at supported window sizes.
10. Do not preserve a legacy layout when it conflicts with this specification.

When existing code conflicts with this document, this document takes precedence.

Do not make the current dashboard merely prettier. Replace incorrect visual structures with the specified composition and visualization system.
