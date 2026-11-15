---
name: Keytone
description: A stack of colored index cards typed on a two-color ribbon typewriter; every keypress leaves a mark.
colors:
  sky-card-stock: "#9ccbe8"
  sky-card-stock-deep: "#84b9db"
  index-white: "#f6f9fb"
  goldenrod-stock: "#f3c85c"
  mint-stock: "#bfe0b6"
  rose-stock: "#f2b8bd"
  tab-stock: "#cfe0ec"
  ribbon-black: "#1e1c1a"
  ribbon-black-soft: "#3d3a36"
  ribbon-black-ghost: "#66625c"
  ribbon-red: "#c4342b"
  ribbon-red-deep: "#9e2620"
  ribbon-red-darkest: "#7a1a15"
  index-rule-blue: "rgba(64, 120, 170, .22)"
  paper-clip-steel: "#7d8892"
typography:
  display:
    fontFamily: "PT Mono, Courier New, monospace"
    fontSize: "clamp(34px, 5.6vw, 66px)"
    fontWeight: 400
    lineHeight: 1.05
    letterSpacing: "-0.01em"
  headline:
    fontFamily: "PT Mono, Courier New, monospace"
    fontSize: "clamp(28px, 3.6vw, 40px)"
    fontWeight: 400
    lineHeight: 1.2
    letterSpacing: "-0.01em"
  title:
    fontFamily: "PT Mono, Courier New, monospace"
    fontSize: "20px"
    fontWeight: 400
    lineHeight: 1.25
    letterSpacing: "-0.01em"
  typing-line:
    fontFamily: "PT Mono, Courier New, monospace"
    fontSize: "22px"
    fontWeight: 400
    lineHeight: "32px"
  lead:
    fontFamily: "Golos Text, system-ui, sans-serif"
    fontSize: "18.5px"
    fontWeight: 400
    lineHeight: "32px"
  body:
    fontFamily: "Golos Text, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.6
  body-ruled:
    fontFamily: "Golos Text, system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: "32px"
  label:
    fontFamily: "PT Mono, Courier New, monospace"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: "32px"
  stamp:
    fontFamily: "PT Mono, Courier New, monospace"
    fontSize: "19px"
    letterSpacing: "0.06em"
rounded:
  focus: "2px"
  card: "3px"
  tab-sm: "6px"
  tab: "7px"
  tab-lg: "8px"
  stamp: "9px"
  hole: "50%"
spacing:
  gutter: "16px"
  rule-pitch: "32px"
  rule-pitch-steps: "40px"
  card-pad: "24px"
  card-pad-hero: "clamp(22px, 5vw, 64px)"
  fan-gap-row: "26px"
  fan-gap-col: "22px"
  section: "100px"
  section-mobile: "76px"
  container: "1080px"
components:
  stamp-primary:
    textColor: "{colors.ribbon-red}"
    typography: "{typography.stamp}"
    rounded: "{rounded.stamp}"
    padding: "14px 24px 13px"
  stamp-primary-hover:
    textColor: "{colors.ribbon-red-deep}"
  stamp-on-mint:
    textColor: "{colors.ribbon-red-deep}"
  stamp-on-mint-hover:
    textColor: "{colors.ribbon-red-darkest}"
  index-card:
    backgroundColor: "{colors.index-white}"
    textColor: "{colors.ribbon-black}"
    rounded: "{rounded.card}"
    padding: "20px 24px 26px"
  index-card-gold:
    backgroundColor: "{colors.goldenrod-stock}"
  index-card-mint:
    backgroundColor: "{colors.mint-stock}"
  index-card-rose:
    backgroundColor: "{colors.rose-stock}"
  index-tab:
    backgroundColor: "{colors.tab-stock}"
    textColor: "{colors.ribbon-black-soft}"
    typography: "{typography.label}"
    rounded: "{rounded.tab-lg}"
    padding: "9px 16px 8px"
  index-tab-active:
    backgroundColor: "{colors.index-white}"
    textColor: "{colors.ribbon-black}"
  nav-tab:
    backgroundColor: "{colors.tab-stock}"
    textColor: "{colors.ribbon-black-soft}"
    rounded: "{rounded.tab}"
    padding: "7px 13px 6px"
  nav-tab-hover:
    backgroundColor: "{colors.index-white}"
    textColor: "{colors.ribbon-black}"
  text-link-typed:
    textColor: "{colors.ribbon-black-soft}"
    typography: "{typography.label}"
  text-link-typed-hover:
    textColor: "{colors.ribbon-red}"
---

# Design System: Keytone

<!-- OPEN DECISIONS (not rules; recorded after the finish review, unscored ceiling items):
- Hero headline does not sit on the 32px rule pitch (line-height 1.05 of a fluid size).
- Red ribbon ink is barely used in typed headings; whether headings should mix black and red is undecided.
- The feature fan is a uniform 3x2 grid; card sizes and stocks may vary later.
- The stamp has no impression left on click.
- Card stock is flat color; paper texture is undecided.
- App icon (Assets/logo.svg, icon-512.png, favicon, apple-touch-icon) still uses the removed dark-navy glow rendering; needs the owner's decision. It is not part of this system.
- The stamp CSS asks for weight 700, but PT Mono ships only 400, so the browser synthesizes bold. The stamp token records no weight until this is resolved.
-->

## Overview

**Creative North Star: "The Two-Color Ribbon Card File"**

Keytone is a stack of colored index cards typed on a two-color ribbon typewriter, and every keypress leaves a mark. The ground is sky-blue card stock with faint white rules; on it sit index cards in near-white, goldenrod, mint and rose stock, each ruled with faint lines at a strict pitch and topped by one red header rule. Everything that is "typed" (headings, labels, tabs, the live demo line, step numbers) is set in a typewriter mono with black or red ribbon ink, and the headings carry uneven inking: every letter sits a hair off its baseline, at a slightly different angle and opacity. Reading text is a quiet humanist sans so the paragraphs stay comfortable.

The world has one primary action and it is a red rubber stamp: a rotated, double-ruled, inked frame whose impression is broken by a procedural mask. Navigation and choice are index tabs that grow out of a card's top edge; the chosen tab is pulled forward and takes the card's color. Ornament is limited to the stationery itself: punched holes and a paper clip. The previous dark-navy SaaS look with glows has been removed; this world replaces it entirely.

Two surfaces carry the world. The download site (Persuade) uses the full palette, the ruled stock and the stamp. The macOS menu-bar panel (Operate) keeps the same world quietly: one near-white card, faint rules, a red header rule, typed headings in red ribbon ink, a goldenrod card only for the one warning, and index tabs for the mouse-sound choice.

Motion is mechanical and short. Easing is `cubic-bezier(.2,.8,.2,1)` at 180-350ms on the site and `easeOut` 140ms in the panel. The one authored moment is the hero headline typing itself at 26-72ms per character. Fan cards straighten and rise 6px on hover. All transitions and animations are disabled under `prefers-reduced-motion`, and the headline appears fully typed.

**Key Characteristics:**
- Sky-blue card-stock ground, cards in four stocks, one red header rule per card.
- Faint ruled lines at a 32px pitch on the site (40px on the install card, 26px in the panel); reading text sits on the rules.
- Two ribbon inks only: black for text, red for accent, headers rules, numbers and the primary action.
- Typed headings with deterministic ink jitter; humanist sans for reading.
- Index tabs for navigation, language and choice; the active tab pulls forward into the card.
- A masked, rotated red rubber stamp as the single primary action.
- Punched holes and a paper clip are the only ornament.

## Colors

Pastel office card stock on a sky-blue desk, typed in black and red ribbon ink.

### Primary
- **Ribbon Red** (ribbon-red): the second color of the typewriter ribbon. Card header rules, the stamp, step numbers 01-04, the FAQ "+", the demo label, the caret, the focus outline, text selection, link hover, and the panel's section headings, header rule, checkmarks, toggles and sliders.
- **Deep Ribbon Red** (ribbon-red-deep): stamp hover, and the stamp's resting ink when it sits on mint stock, where plain ribbon red loses contrast.
- **Darkest Ribbon Red** (ribbon-red-darkest): stamp hover on mint stock only.

### Secondary
- **Goldenrod Stock** (goldenrod-stock): feature cards, the install card, and in the panel the permission warning card and the active mouse-sound tab with its underline strip.
- **Mint Stock** (mint-stock): feature card and the closing card.
- **Rose Stock** (rose-stock): feature card and the FAQ card.

### Neutral
- **Sky Card Stock** (sky-card-stock): the page ground, with white rules (`rgba(255,255,255,.18)`) at the 32px pitch. Also the browser `theme-color` and the color seen through punched holes.
- **Deep Sky Stock** (sky-card-stock-deep): the scrollbar track.
- **Index White** (index-white): the hero card, plain feature cards, the strip the nav tabs grow from, active tabs, and the whole panel background (`Theme.card`).
- **Tab Stock** (tab-stock): resting tabs on the site. The panel's tab stock is lighter (`Theme.tab`, about #dfe9f0) and also tints the panel footer at 60% and row hover at 70%.
- **Ribbon Black** (ribbon-black): all primary text, both surfaces.
- **Soft Ribbon Black** (ribbon-black-soft): secondary text, leads, card paragraphs, resting tab labels, footer. The panel's soft ink is a touch lighter (`Theme.inkSoft`, about #4d4a45).
- **Ghost Ribbon** (ribbon-black-ghost): the placeholder in the live typing line only.
- **Index Rule Blue** (index-rule-blue): ruled lines on index-white cards and in the panel. Colored stocks tint their own rules: goldenrod `rgba(140,90,0,.16)`, mint `rgba(40,100,50,.16)`, rose `rgba(140,40,60,.14)`.
- **Paper Clip Steel** (paper-clip-steel): the paper clip stroke.

### Named Rules
**The Two Ribbons Rule.** Ink comes in two colors, black and red. There is no third accent; colored stock is paper, not ink, and never carries text color.

**The One Red Rule Per Card Rule.** Each card's heading hangs a single 2px ribbon-red rule that runs edge to edge across the card (1.5px under the panel header). Do not add more red rules to the same card.

**The Stock Carries Its Own Rules Rule.** Ruled lines are tinted toward their card's stock, never a single global gray, and they stay faint (14-22% alpha).

## Typography

**Display Font:** PT Mono (with Courier New, monospace)
**Body Font:** Golos Text (with system-ui, sans-serif)
**Panel Font:** SF Mono via the system monospaced design for typed text; SF Pro for reading text (cited adaptation: native panels keep platform faces).

**Character:** A typewriter mono for everything that was "typed onto the card" and a warm humanist sans for anything meant to be read at length. The mono is always weight 400 on the site; uneven inking, not weight, gives it character.

### Hierarchy
- **Display** (400, clamp(34px, 5.6vw, 66px), 1.05, max 15ch): the hero headline, typed onto the card letter by letter at load.
- **Headline** (400, clamp(28px, 3.6vw, 40px)): section titles sitting on the sky ground. The closing card heading uses clamp(26px, 3.4vw, 36px).
- **Title** (400, 20px, 1.25): feature-card headings, each with the red header rule.
- **Typing line** (400, 22px / 32px; 18px on phones): the live demo line with a red underscore caret.
- **Lead** (Golos 400, 18.5px / 32px, max 52ch): the hero paragraph, on the rules.
- **Body** (Golos 400, 17px / 1.6; 16px on phones): default text. Card paragraphs use 16px on the 32px rule line; FAQ answers cap at 66ch; install steps use 17px on the 40px rule.
- **Label** (PT Mono 400, 13-15px): tabs (14px), language tabs (13px uppercase), the demo label (14px, red), requirements (14px / 32px), source link (15px), footer (14px), FAQ questions (18px).
- **Stamp** (PT Mono, 19px; 16px on phones, uppercase, 0.06em tracking): the stamp face only.

Panel scale: brand 15 medium mono; section headings 12 medium mono in red; pack names 13 mono (semibold when chosen); tab labels 12 mono; buttons 11.5 medium mono; option labels 12.5 sans; secondary 11-11.5 sans.

### Named Rules
**The Uneven Ribbon Rule.** Typed headings are inked letter by letter: each character gets a deterministic offset of up to ±0.8px vertical, ±0.7deg rotation and 80-100% opacity, seeded from the text so it is stable across renders. Words never break mid-word. Typed demo characters use ±0.9px and 74-100% opacity.

**The Typed vs Read Rule.** If it is a heading, label, tab, number, code or button, it is typed in mono. If it is a sentence to read, it is Golos Text. Never set paragraphs in the mono.

## Layout

A single centered column, `min(1080px, 100% - 32px)`, giving a 16px side gutter at phone width. The page is a desk with cards laid on it: a header strip with tabs, one large hero card nearly full width, then sections separated by 100px (76px under 640px), each a headline on the ground followed by a card or a fan of cards.

The vertical rhythm is the rule pitch. The ground and cards are ruled every 32px, and reading lines inside cards (lead, card paragraphs, notes, requirements, demo label) are set at a 32px line height so text sits on the rules. The install card is ruled every 40px with a 40px line height and a red vertical margin rule; step numbers 01-04 are typed in red in a 92px margin column (58px on phones). The panel rules every 26px under its header.

Feature cards form a loose fan: a 3-column grid (26px row, 22px column gap), 2 columns under 900px, 1 under 580px. Each card is rotated -1.4deg to 1.2deg with small vertical offsets; on phones rotation is removed. Card padding is 24px by default, clamp(22px, 5vw, 64px) on the hero, 34px on the closing card. The red header rule bleeds to the card edges through negative margins equal to the card padding.

The panel is a fixed 320pt column: header (13/12pt vertical, 16pt horizontal), body sections at 16pt spacing, footer strip on 60% tab stock.

## Elevation & Depth

Depth is paper on a desk: cards cast a soft three-layer lift shadow, and everything else is flat. Tabs have no shadow; they read as part of the card by sharing its color and shifting vertically. Punched holes are the inverse: an inset shadow shows the ground through the card.

### Shadow Vocabulary
- **Card lift** (`box-shadow: 0 1px 1px rgba(30,40,60,.12), 0 6px 14px -4px rgba(30,40,60,.22), 0 22px 40px -18px rgba(30,40,60,.3)`): every card on the site.
- **Tab strip** (`box-shadow: 0 2px 4px -2px rgba(30,40,60,.25)`): the 4px card-stock strip under the header nav.
- **Punched hole** (`box-shadow: inset 0 2px 3px rgba(20,40,70,.35)`): 18px holes at the bottom center of the hero and closing cards.
- **Panel warning card** (SwiftUI `.shadow(color: .black.opacity(0.12), radius: 3, y: 2)`): the goldenrod permission card only.

### Named Rules
**The Paper Not Light Rule.** Shadows are cool, low-alpha and fall downward like paper on a desk. No glows, no colored shadows, no blur behind surfaces.

## Shapes

Cards are nearly square-cornered (3px), like cut card stock. Tabs round only their top corners (6-8px) and stay square at the bottom where they meet the card. The stamp is a rounded rectangle (9px) with a 3px ink border plus an inset 2px ring 2px inside it, giving the double rule of a rubber stamp; it rests rotated -3.5deg and its whole face is masked by a procedural impression texture (`docs/assets/stamp-mask.png`, from `Assets/make_stamp_mask.swift`): heavy rim, pinhole voids, dry streaks. Punched holes are 18px circles. The paper clip is a 22x56 stroked wire path that overlaps a card's top edge. Focus is a 2px dashed red outline with a 3px offset (6px on the typing line).

In the panel: cards and row highlights 3pt, buttons 5pt, tab tops 6pt.

## Components

### Buttons
Tactile and inked: the primary action is a stamp, everything else is typed text or plain card stock.
- **Stamp (primary):** ribbon-red ink on transparent, 3px border with the inner ring, 9px radius, 14px 24px 13px padding, uppercase mono with 0.06em tracking, a 20px stroked download glyph, rotated -3.5deg, masked impression. On mint stock it inks in deep red.
- **Hover / Active:** hover straightens to -1.5deg, scales 1.03 and deepens the ink; active presses to scale .95 at -2deg with a 60ms transition. Easing `cubic-bezier(.2,.8,.2,1)`, 180ms.
- **Typed link (secondary):** 15px mono in soft ink with an underline offset 5px; hover turns ribbon red.
- **Panel flat button:** 26pt high, 5pt radius, card stock with a 1pt soft-ink border at 35%, 11.5 medium mono with a 10pt SF Symbol. Hover fills with tab stock. The prominent variant inks text and a 1.5pt border in red, echoing the stamp.

### Index Tabs (navigation, language, pack selector)
- **Style:** mono 13-14px in soft ink on tab stock, top corners rounded, resting a few px low (2px nav, 3px language, 6px pack tabs) so they look tucked behind the card.
- **State:** active or hovered tabs take the card's stock (index white) and ink, and rise to 0; pack tabs lift halfway (2px) on hover. Transition 200-250ms `cubic-bezier(.2,.8,.2,1)`. Under 720px the section nav tabs hide, leaving GitHub and language.
- **Panel:** mouse-sound tabs fill the width with 3pt gaps, 24pt high; the chosen tab fills goldenrod, drops its 2pt offset, and sits on a 2pt goldenrod strip.

### Cards / Containers
- **Corner Style:** 3px.
- **Background:** index white, goldenrod, mint or rose stock, each with its own tinted rules.
- **Shadow Strategy:** card lift (see Elevation & Depth).
- **Border:** none; the red header rule under the heading is the only line.
- **Internal Padding:** 24px default, 20px top / 26px bottom on feature cards, clamp(22px, 5vw, 64px) on the hero.
- **FAQ card:** unruled rose stock; questions are typed 18px with a red "+" that turns 45deg when open; items separated by dashed rose-ink rules.

### Live Typing Line (signature)
A focusable textbox on the hero card where the visitor's keystrokes are typed in 22px mono with per-letter ink jitter and a blinking red underscore caret (1.05s steps). Each keydown and keyup plays a synthesized "thock" matched to the selected pack tab; the page labels it as an approximation.

### Panel Rows and Controls
- **Pack row:** 26pt high, 6pt horizontal padding; a heavy red checkmark scales in when chosen and the name turns semibold; hover fills tab stock at 70%. Custom packs reveal a trash glyph on hover.
- **Toggles and sliders:** native mini controls tinted ribbon red.
- **Section heading:** 12 medium mono in ribbon red, optional trailing toggle.


## Do's and Don'ts

### Do:
- **Do** set reading lines inside cards on the 32px rule pitch (or 40px on the install card) so text sits on the rules.
- **Do** give every card exactly one 2px ribbon-red header rule that bleeds to its edges.
- **Do** ink typed headings through the uneven-ribbon jitter, seeded from the text.
- **Do** make the stamp the only primary action, and ink it deep red on mint stock.
- **Do** use index tabs for any choice between a few options, with the active tab pulled forward in the card's color.
- **Do** keep the panel light (`preferredColorScheme(.light)`), on index-white stock with red as its only accent.
- **Do** label any synthesized sound on the site as an approximation.

### Don't:
- **Don't** reintroduce the dark-navy SaaS look: no glows, gradients-as-light, or glowing product shots.
- **Don't** add a third ink color; goldenrod, mint and rose are paper stock, never text.
- **Don't** set paragraphs in the mono or headings in the sans.
- **Don't** add ornament beyond punched holes and the paper clip.
- **Don't** add small uppercase labels above headings; the red header rule already marks a heading.
- **Don't** rotate cards on phones; the fan flattens under 580px.
