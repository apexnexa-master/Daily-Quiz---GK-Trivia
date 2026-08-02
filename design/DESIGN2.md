---
name: Hyper-Glass Kinetic
colors:
  surface: '#0d1515'
  surface-dim: '#0d1515'
  surface-bright: '#333b3b'
  surface-container-lowest: '#080f10'
  surface-container-low: '#151d1e'
  surface-container: '#192122'
  surface-container-high: '#232b2c'
  surface-container-highest: '#2e3637'
  on-surface: '#dce4e4'
  on-surface-variant: '#b9cacb'
  inverse-surface: '#dce4e4'
  inverse-on-surface: '#2a3232'
  outline: '#849495'
  outline-variant: '#3a494b'
  surface-tint: '#00dbe7'
  primary: '#ddfcff'
  on-primary: '#00363a'
  primary-container: '#00f1fe'
  on-primary-container: '#006a70'
  inverse-primary: '#00696f'
  secondary: '#ecb2ff'
  on-secondary: '#520071'
  secondary-container: '#cf5cff'
  on-secondary-container: '#480063'
  tertiary: '#fff6e3'
  on-tertiary: '#3b2f00'
  tertiary-container: '#ffd73a'
  on-tertiary-container: '#725d00'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#74f5ff'
  primary-fixed-dim: '#00dbe7'
  on-primary-fixed: '#002022'
  on-primary-fixed-variant: '#004f54'
  secondary-fixed: '#f8d8ff'
  secondary-fixed-dim: '#ecb2ff'
  on-secondary-fixed: '#320047'
  on-secondary-fixed-variant: '#74009f'
  tertiary-fixed: '#ffe179'
  tertiary-fixed-dim: '#eac324'
  on-tertiary-fixed: '#231b00'
  on-tertiary-fixed-variant: '#554500'
  background: '#0d1515'
  on-background: '#dce4e4'
  surface-variant: '#2e3637'
typography:
  display-lg:
    fontFamily: Montserrat
    fontSize: 48px
    fontWeight: '800'
    lineHeight: '1.1'
    letterSpacing: -0.04em
  display-sm:
    fontFamily: Montserrat
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Montserrat
    fontSize: 24px
    fontWeight: '700'
    lineHeight: '1.3'
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Montserrat
    fontSize: 20px
    fontWeight: '600'
    lineHeight: '1.4'
    letterSpacing: 0em
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
    letterSpacing: 0em
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
    letterSpacing: 0em
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: '1'
    letterSpacing: 0.1em
  display-lg-mobile:
    fontFamily: Montserrat
    fontSize: 36px
    fontWeight: '800'
    lineHeight: '1.1'
    letterSpacing: -0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  container-padding-mobile: 20px
  container-padding-desktop: 40px
  stack-gap: 24px
  glass-padding: 16px
---

## Brand & Style

This design system targets elite mental performance through a "Hyper-Glass" aesthetic. It merges high-performance sports aesthetics with futuristic digital interfaces. The visual narrative centers on deep layering, light refraction, and kinetic energy.

**Style: Hyper-Glass / Neo-Futurism**
- **Depth:** Multi-layered surfaces utilizing varying levels of transparency and backdrop-blur.
- **Atmosphere:** High-performance, premium, and focused. The UI should feel like a sophisticated cockpit for the mind.
- **Visual Cues:** Glowing interactive states, sharp light-bleed on borders, and high-fidelity motion.

## Colors

The palette is optimized for OLED displays and high-contrast environments. 

- **Electric Cyan:** Used for primary actions, progress indicators, and active mental states.
- **Neon Violet:** Used for secondary metrics, flow states, and depth-level accents.
- **Surface (Ultra-dark charcoal):** The foundation of the UI, providing the "infinite depth" required for glass effects to pop.
- **Glass Overlays:** Surfaces use a 10% white opacity with `backdrop-filter: blur(24px)` to create a frosted, premium feel.

## Typography

Typography is a critical driver of the "performance" feel.

- **Headlines:** Use **Montserrat** with tight tracking and heavy weights to evoke strength and urgency.
- **Body:** Use **Inter** for its systematic clarity and readability against dark, textured backgrounds.
- **Labels:** Use uppercase Inter for metadata and technical specs to reinforce the futuristic, data-driven theme.

## Layout & Spacing

The layout follows a **fluid, modular grid** system designed for immersion.

- **Safe Zones:** Use generous outer margins (20px mobile / 40px desktop) to let the glass containers breathe.
- **Card Layouts:** Elements should feel floating. Use a 12-column grid for desktop where glass panels typically span 4 or 6 columns.
- **Z-Axis Spacing:** Use vertical spacing to imply depth; higher priority items should have larger margins to feel more isolated and prominent.

## Elevation & Depth

Hierarchy is established through "The Stack"—a series of glass layers.

- **Level 0 (Base):** Ultra-dark charcoal (#0E1416) with subtle radial gradients of Cyan and Violet in the corners (10% opacity).
- **Level 1 (Panels):** Backdrop-blur (24px) with a 1px solid border at 10% white. Soft ambient shadow: `0 20px 40px rgba(0,0,0,0.4)`.
- **Level 2 (Active Elements):** Primary buttons or active cards. Add a subtle outer glow using the primary color (`box-shadow: 0 0 15px rgba(0, 241, 254, 0.3)`).
- **Interaction:** On hover, glass surfaces should increase in opacity from 10% to 15% and the border brightness should double.

## Shapes

The design system uses **Rounded (0.5rem base)** geometry to balance the aggressive "Electric" colors with a premium, ergonomic feel.

- **Standard Containers:** 16px (1rem) corner radius for cards and glass panels.
- **Interactive Elements:** 8px (0.5rem) for buttons and inputs.
- **Data Points:** Small chips or tags use a full pill-shape to distinguish them from structural UI components.

## Components

- **Glass Buttons:** Primary buttons use a solid Electric Cyan with black text for maximum contrast. Secondary buttons use a glass background with a Cyan 1px border.
- **Performance Chips:** Small, semi-transparent capsules used to display brain metrics (e.g., "Focus: 92%"). These use Neon Violet accents.
- **Kinetic Lists:** List items should be separated by a 1px divider (white/5) or contained in individual glass tiles with subtle vertical stacking.
- **Input Fields:** Minimalist design with only a bottom border that "activates" with a Cyan glow transition upon focus.
- **Metric Cards:** High-translucency containers featuring bold Montserrat display numbers and micro-sparkline charts in Electric Cyan.
- **Glow Accents:** Use "Light Bleed" components—0.5px thick lines that use a linear gradient from transparent to Electric Cyan to transparent—to separate sections or highlight edges.