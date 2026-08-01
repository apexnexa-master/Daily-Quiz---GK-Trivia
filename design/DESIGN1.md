---
name: Hyper-Natural Cognitive
colors:
  surface: '#111318'
  surface-dim: '#111318'
  surface-bright: '#37393e'
  surface-container-lowest: '#0c0e12'
  surface-container-low: '#1a1c20'
  surface-container: '#1e2024'
  surface-container-high: '#282a2e'
  surface-container-highest: '#333539'
  on-surface: '#e2e2e8'
  on-surface-variant: '#c5c9af'
  inverse-surface: '#e2e2e8'
  inverse-on-surface: '#2f3035'
  outline: '#8e937b'
  outline-variant: '#444935'
  surface-tint: '#add525'
  primary: '#ffffff'
  on-primary: '#283500'
  primary-container: '#c8f244'
  on-primary-container: '#556d00'
  inverse-primary: '#506600'
  secondary: '#d3bbff'
  on-secondary: '#3f008d'
  secondary-container: '#5d03ca'
  on-secondary-container: '#c7aaff'
  tertiary: '#ffffff'
  on-tertiary: '#2d3037'
  tertiary-container: '#e1e2ea'
  on-tertiary-container: '#62646b'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#c8f244'
  primary-fixed-dim: '#add525'
  on-primary-fixed: '#161f00'
  on-primary-fixed-variant: '#3c4d00'
  secondary-fixed: '#ebddff'
  secondary-fixed-dim: '#d3bbff'
  on-secondary-fixed: '#250059'
  on-secondary-fixed-variant: '#5b00c5'
  tertiary-fixed: '#e1e2ea'
  tertiary-fixed-dim: '#c4c6ce'
  on-tertiary-fixed: '#191c22'
  on-tertiary-fixed-variant: '#44474d'
  background: '#111318'
  on-background: '#e2e2e8'
  surface-variant: '#333539'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '800'
    lineHeight: '1.1'
    letterSpacing: -0.04em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.5'
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '700'
    lineHeight: '1.0'
    letterSpacing: 0.1em
  mono-metric:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1.0'
    letterSpacing: 0.05em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  gutter: 16px
  margin-mobile: 20px
  margin-desktop: 40px
  container-max: 1200px
---

## Brand & Style
The design system embodies "Hyper-Naturalism"—a fusion of biological rhythm and high-performance computing. It targets high-agency individuals seeking cognitive optimization. The aesthetic moves away from standard SaaS minimalism toward a "Tactical Premium" feel.

The style leverages **Modern Minimalism** with **High-Contrast** accents. It utilizes a void-like background to eliminate visual noise, allowing the "Cyber-Lime" to act as a bio-luminescent trigger for action. The interface should feel like a high-end physiological HUD—precise, responsive, and authoritative.

## Colors
The palette is engineered for focus and circadian awareness. 
- **Base (Obsidian):** #0A0C10. Used for the primary canvas to reduce eye strain and maximize contrast.
- **Surface (Graphite):** #1A1D23. Used for cards, modals, and segregated sections to provide subtle depth without breaking the dark-mode immersion.
- **Action (Cyber-Lime):** #D4FF50. Reserved for high-priority calls to action (CTAs), progress indicators, and active states.
- **Insight (Deep Violet):** #6D28D9. Used for data visualization, "flow state" indicators, and secondary navigational elements that require cognitive depth.

## Typography
The system uses **Inter** exclusively to maintain technical clarity and a systematic feel. Distinctiveness is achieved through extreme weight variance and tight letter-spacing on larger headers.

Headlines must be set with negative letter-spacing to create a "dense" and "impactful" presence. Body copy remains airy for legibility. For data points (e.g., heart rate, focus scores), use the `label-caps` or `mono-metric` style to evoke a laboratory or cockpit instrument feel.

## Layout & Spacing
This design system utilizes a **Fluid Grid** with fixed margins. The spacing scale is built on a 4px baseline to ensure mathematical precision.

- **Mobile:** 4-column layout with 20px side margins and 16px gutters.
- **Desktop:** 12-column layout with a maximum container width of 1200px.
- **Rhythm:** Use large vertical padding (80px+) between major sections to emphasize focus and prevent information density fatigue.

## Elevation & Depth
Depth is created through **Tonal Layers** rather than traditional shadows. 
- **Level 0 (Background):** #0A0C10.
- **Level 1 (Containers):** #1A1D23. 
- **Accents:** Use 1px solid strokes for container borders using a 10% opacity white to define edges without adding visual weight.

For high-priority modals, a subtle **Backdrop Blur** (20px) is applied to the background to maintain context while isolating the current cognitive task. Avoid drop shadows; use "Cyber-Lime" outer glows (5px blur, 20% opacity) only for elements in an "active" or "peak" state.

## Shapes
The shape language follows a "Precision-Organic" hybrid:
- **Structural Containers:** Use a strict **12px (0.75rem)** radius. This provides a modern, professional structure for content blocks and cards.
- **Interactive Elements:** Buttons, chips, and toggles use a **Full Pill (9999px)** radius. This signals biological comfort and high-speed interaction.
- **Inputs:** Use the 12px container radius to maintain alignment with the grid.

## Components
- **Buttons:** Primary buttons are Cyber-Lime with black text, full-pill shape. Secondary buttons use a Graphite fill with a 1px white-border (10% opacity).
- **Chips:** Small, full-pill shapes using Deep Violet for category tags or "Focus Mode" indicators.
- **Cards:** Graphite background (#1A1D23) with 12px rounded corners. No shadow, just a subtle 1px border.
- **Input Fields:** Darker than the surface (#0F1115), 12px radius. On focus, the border transitions to a 1px Cyber-Lime stroke.
- **Progress Bars:** Use a "Biometric" style—thin tracks with high-glow Cyber-Lime fills.
- **Data Visuals:** Use Deep Violet for historical data and Cyber-Lime for real-time/current data to differentiate between "stored" and "active" information.