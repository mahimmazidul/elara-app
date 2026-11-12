# Why Elara's Today screen did not feel right, and what changed

> **Updated in 2.2.1.** The diagnosis below was right and the fix was half of
> it. It moved the hero to a deeper value and rebuilt Today around one object,
> but it left the *ground* warm: a beige page (#F7F3EF), a dusty hero, and four
> phase fills that sat between CIELAB C* 19 and C* 43 — sage barely coloured,
> honey strongly coloured. The page was still carrying a tint of its own, so the
> four dyes were being printed on coloured paper.
>
> 2.2.1 finishes the sentence: the page is a neutral (#F6F6F4, C* 1.0), the card
> is white, the four dyes are solved to one weight (L* 62, C* 36 at each hue),
> the honey accent is retired so the accent is the active phase's own dye, and
> the four hero panels are solved to one lightness with cream ink at 4.9:1 or
> better. Every number on this page that refers to the old palette is left as
> written, because it is the record of what was measured at the time; the values
> to change are in `lib/theme/elara_theme.dart` and the `:root` block of
> `docs/index.html`.

Written after the third "the colours feel like shit" report, on the theory that
the third complaint about the same thing is not a taste problem — it is a
diagnosis I keep failing to make. The reference was taka's home screen, which
uses a much louder colour than Elara ever did, and looks calmer.

## The diagnosis, in one line

**taka puts its colour in one place and lets everything else be quiet. Elara
spread a pale version of its colour everywhere and put the loud version nowhere.**

That is the whole thing. Everything below is detail.

## What taka actually does

Looking at `docs/screenshots/home_light.png` next to any Elara screenshot:

1. **One saturated object per screen.** The green balance card at the top. It is
   the biggest thing on the page, it is the only thing at full saturation, and
   everything below it is white, grey ink and hairlines. The eye lands, then
   reads.
2. **Two values of the accent, not five.** The green appears as one solid block,
   one small icon tint, one number, and a hairline on a selected segment.
   Nothing is *washed*: there is no 20%-opacity green anywhere.
3. **Hierarchy by weight and colour of ink, not by boxes.** The stat strip is
   three numbers separated by hairlines. No card, no shadow, no tint.
4. **Corners are consistent and generous** — 24-28 on the hero, 999 on pills,
   12 on small tiles — and the bar has a floating pill with a filled centre
   target, so the bar reads as an object rather than as a strip of the page.
5. **Selected state fills the icon**, not a line under it. Instant to read.

## What Elara was doing

1. **Colour at 2–3:1 contrast, spread across geometry.** The phase fills
   (`#C98C90`, `#7FA894`, `#D2A45F`, `#9384B6`) are *tints*. On a 3.5 dp ring,
   a dot and a chip they read as jewellery. Everywhere else — the app's accent,
   the tab indicator, the nav label — they read as **faded**, because a tint at
   panel scale is what "washed out" means. A page cannot be quiet and pale at the
   same time: pale is the thing that makes a screen look cheap, and quiet is
   what you get from *size and contrast*, not from desaturation.
2. **No focal object.** Ring on paper, text under it, sentence under that, card
   below. The most important thing on the screen had the same visual weight as
   the list of links at the bottom. There was nothing to land on.
3. **Wrong bar selected state.** A travelling dot slid under the tab, in a phase
   colour chosen by tab index — honey under "Today" on a violet luteal day. Two
   different colours, one screen, no meaning to either.
4. **The palette is warm-neutral, and neutral reads as unfinished.** `#F7F3EF`
   page with `#FFFDFB` cards is a 1.09:1 difference. Cards separated only by a
   hairline is a fine editorial system (it is what taka does), but Elara mixed
   it with shadows and glass, so it looked like a card system that failed rather
   than a line system that succeeded.
5. **Six accent families competing**: four phase colours, a honey accent, sage
   success, amber warning, rose danger. Taka runs one accent and one semantic
   red. Anything past two starts to look like a default theme.

## What changed in 2.2.0

- **A hero panel.** One saturated block per screen, carrying phase, dial and
  countdown together. Fill from a new `heroFill` token: the same four dyes taken
  down to values that clear 5.0–8.0:1 with cream ink (`#A63E52`, `#2E6F58`,
  `#8F5A0E`/`#9A5F0C`, `#56447F`). The decorative tints stay where they were —
  ring, dot, wash, chip — because that is the size at which a tint works.
- **The dial became a wheel.** One tick per day of the cycle, elapsed ticks in
  ink, a dot for today, moon inside. A continuous 72% arc says "mostly"; ticks
  say *which day*, and give the ring a texture that reads as a made object.
- **The bar marks the tab by filling its icon**, in a wash of the *theme* accent,
  so the bar and the panel are the same colour on the same day. The travelling
  underline is gone.
- **One ink hierarchy inside the panel** (100% / 78% / 72% cream) instead of
  three borrowed tokens.
- **The website picks it up**: the page wash, the download button and the phase
  strip now all take today's colour, so the theme changes as a page rather than
  as a swapped screenshot.

## What I did *not* do, and why

- **Didn't desaturate further.** Going paler is what created the problem.
- **Didn't add gradients, blurs or a second shadow.** Taka uses none of these;
  the calm comes from restraint, not from effects.
- **Didn't switch the four phase colours.** They are load-bearing: menstrual
  rose, follicular sage, ovulatory honey, luteal violet is a legible, non-alarm
  vocabulary, and it survives the Bangla UI. What was wrong was the *value* they
  were used at, not the hues.

## The rule to keep

One saturated panel per screen. Everything else is paper, ink and a hairline. A
tint is for a 6 px stroke and never for a 340 px block.
