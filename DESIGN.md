---
name: Harmonia Lar
colors:
  surface: '#fdf9f4'
  surface-dim: '#ddd9d5'
  surface-bright: '#fdf9f4'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f7f3ee'
  surface-container: '#f1ede8'
  surface-container-high: '#ebe8e3'
  surface-container-highest: '#e6e2dd'
  on-surface: '#1c1c19'
  on-surface-variant: '#54433e'
  inverse-surface: '#31302d'
  inverse-on-surface: '#f4f0eb'
  outline: '#87736d'
  outline-variant: '#dac1ba'
  surface-tint: '#944931'
  primary: '#944931'
  on-primary: '#ffffff'
  primary-container: '#d67d61'
  on-primary-container: '#551905'
  inverse-primary: '#ffb59e'
  secondary: '#536346'
  on-secondary: '#ffffff'
  secondary-container: '#d6e9c3'
  on-secondary-container: '#59694b'
  tertiary: '#735b26'
  on-tertiary: '#ffffff'
  tertiary-container: '#ad9157'
  on-tertiary-container: '#3c2b00'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdbd0'
  primary-fixed-dim: '#ffb59e'
  on-primary-fixed: '#3a0b00'
  on-primary-fixed-variant: '#76321c'
  secondary-fixed: '#d6e9c3'
  secondary-fixed-dim: '#bacca8'
  on-secondary-fixed: '#111f08'
  on-secondary-fixed-variant: '#3c4b30'
  tertiary-fixed: '#ffdf9f'
  tertiary-fixed-dim: '#e2c383'
  on-tertiary-fixed: '#261a00'
  on-tertiary-fixed-variant: '#594410'
  background: '#fdf9f4'
  on-background: '#1c1c19'
  surface-variant: '#e6e2dd'
typography:
  display-lg:
    fontFamily: Montserrat
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -1px
  headline-lg:
    fontFamily: Montserrat
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
  headline-lg-mobile:
    fontFamily: Montserrat
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 30px
  title-md:
    fontFamily: Montserrat
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Montserrat
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Montserrat
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-caps:
    fontFamily: Montserrat
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 1px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  margin-mobile: 24px
  gutter-mobile: 16px
  padding-card: 20px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
---

## Brand & Style

The brand personality is rooted in the concept of "Equilíbrio Afetivo" (Affective Balance). It aims to transform household management from a source of friction into a collaborative, rewarding experience. The target audience consists of modern cohabitants (couples, roommates, or families) who value fairness and aesthetic tranquility.

The design style is **Geometric Minimalist Cozy**. This approach combines the structural clarity of Swiss design with a warm, "hygge" inspired palette. The visual language uses primitive geometric shapes—circles, arcs, and squares—to create a sense of order, while the soft colors and large corner radii ensure the interface feels approachable and non-punitive. Illustrations should consist of flat, abstracted geometric characters that emphasize movement and togetherness without unnecessary detail.

## Colors

The palette avoids the sterile whites and harsh blues of traditional productivity apps, opting instead for an "Earth & Sand" foundation.

- **Primary (Terracotta):** Used for main actions, active states, and the "Treta" difficulty level. It represents energy and the "work" of the home.
- **Secondary (Sage):** Represents the "Mamão" difficulty and completion. It evokes peace, growth, and resolved tasks.
- **Tertiary (Sand):** Used for the "Embaçada" difficulty and highlighting secondary information. It adds warmth without the urgency of the primary color.
- **Neutral (Cream/Off-white):** Provides a soft, low-glare background that makes the geometric shapes pop without creating eye strain.

Color blocking is preferred over lines or dividers to separate sections, using subtle shifts between the canvas and surface tones.

## Typography

This design system utilizes **Montserrat** across all levels to maintain a consistent geometric rhythm. The font’s open counters and circular shapes mirror the UI’s rounded containers.

- **Headlines:** Use heavy weights (700) to create a clear visual hierarchy against the flat backgrounds.
- **Body:** Set with generous line heights (1.5x) to ensure task descriptions feel breezy and easy to read.
- **Labels:** Use "Label-Caps" for difficulty badges and status indicators to provide a distinct stylistic break from conversational text.
- **Localization:** Ensure all typography is tested for Portuguese (pt-BR) word lengths, which are often 20-30% longer than English.

## Layout & Spacing

The layout follows a **Fluid Grid** model designed for mobile-first consumption. 

- **Margins:** A generous 24px side margin is used to give content "room to breathe," enhancing the cozy minimalist feel.
- **Rhythm:** An 8px base unit controls all padding and stacking. 
- **Task View:** Use a single-column stack for task lists to maximize readability.
- **Dashboard:** For the overview, use a 2-column masonry or balanced grid to show "Poeira na Pá" (currency) and progress circles side-by-side.
- **Visual Safety:** Avoid placing text too close to the edges of rounded containers; maintain a minimum 16px internal padding.

## Elevation & Depth

This design system utilizes **Tonal Layers** supplemented by **Ambient Shadows** to create a soft, tactile depth.

- **Surface Levels:** The background canvas is the lowest layer. Cards and containers sit one level above, distinguished by a subtle color shift (e.g., Cream surface on Off-white canvas).
- **Shadows:** Avoid pure black or grey shadows. Use "Warm Ambient" shadows: a low-opacity (8-10%) version of the Terracotta or Sage colors, heavily diffused (Blur: 16px, Y: 4px) to suggest a gentle lift rather than a hard float.
- **Active State:** Elements like buttons or selected task cards use a slight "press-in" effect—removing the shadow and deepening the background color to simulate physical interaction.

## Shapes

The shape language is the core of the "Geometric" aesthetic.

- **Corner Radii:** Primary cards use a 24px radius to feel soft and safe. Interactive elements like buttons use a 16px radius. 
- **Geometric Primitives:** Progress trackers should be perfect circles or thick-stroked arcs. Avoid sharp corners entirely.
- **The "Poeira na Pá" Icon:** This currency icon is a stylized geometric sparkle/cloud. It should be constructed from four intersecting circles of varying sizes, forming a soft "puff" shape, rendered in the Sand/Yellow palette.

## Components

### Buttons
Primary buttons are solid Terracotta with white text, featuring 16px rounded corners. Secondary buttons use a Sage outline or a flat Cream background with Sage text.

### Difficulty Badges
These are pill-shaped tags (100px radius) with a light tinted background and dark text of the same hue:
- **Mamão 🥭:** Background: Sage-light; Text: Sage-dark.
- **Embaçada 😅:** Background: Sand-light; Text: Sand-dark.
- **Treta 😤:** Background: Terracotta-light; Text: Terracotta-dark.

### Task Cards
Cards are the primary container. They use the 24px radius and a very soft ambient shadow. They should include:
- A large geometric icon on the left (e.g., a circle for laundry, a square for cleaning).
- The task title in `title-md`.
- The difficulty badge at the bottom right.
- The "Poeira na Pá" reward value next to the sparkle icon.

### Progress Circles
Use thick, rounded stroke caps for circular progress bars. When a user reaches their daily goal, the circle should pulse gently and transition from Sand to Sage.

### Input Fields
Inputs are borderless, using a slightly darker Cream background than the card they sit on. Focused states are indicated by a 2px Sage bottom border.