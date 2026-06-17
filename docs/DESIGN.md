---
name: SRS Patrol System
description: Visual Design System for the Skim Rondaan Sukarela digital app
colors:
  primary: "#0F3D87"
  secondary: "#FFD100"
  neutral-bg-light: "#F8F9FA"
  neutral-bg-dark: "#121212"
  surface-light: "#FFFFFF"
  surface-dark: "#1E1E1E"
typography:
  display:
    fontFamily: "System default"
    fontSize: "20px"
    fontWeight: 600
    letterSpacing: "0.5px"
  body:
    fontFamily: "System default"
    fontSize: "14px"
    fontWeight: "normal"
    letterSpacing: "normal"
rounded:
  sm: "8px"
  md: "16px"
  lg: "20px"
components:
  card:
    backgroundColor: "{colors.surface-light}"
    rounded: "{rounded.md}"
    padding: "8px 16px"
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.surface-light}"
    rounded: "{rounded.md}"
    padding: "16px 24px"
---

## Overview
This design system ensures a highly accessible, trustworthy, and official interface for Voluntary Patrol Scheme (SRS) community members and organizers. It supports a clean layout with strong typography contrast and unified sizing rules.

## Colors
- **Primary**: `#0F3D87` (Deep Navy) - AppBar, primary buttons, highlighted text, and active navigation indicators. Represents official authority and security.
- **Secondary (Accent)**: `#FFD100` (Malaysian Yellow) - Alert highlights, badges, and warning states.
- **Background**:
  - Light mode: `#F8F9FA` (Soft Cool Grey/White).
  - Dark mode: `#121212` (Pure dark grey).
- **Surface**:
  - Light mode: `#FFFFFF` (White) - Card containers, bottom sheets, dialogs.
  - Dark mode: `#1E1E1E` (Dark Grey) - Card containers, bottom sheets, dialogs.

## Typography
- **AppBar Titles**: Display style with font size 20px, bold (w600), and letter-spacing 0.5px.
- **Buttons**: font size 16px, bold, letter-spacing 1px.
- **Body / Labels**: Dynamic system fonts (Roboto/San Francisco) to honor system-wide accessibility adjustments.

## Elevation
- **Elevations (Material 3 style)**:
  - Cards: elevation 3, soft shadow `#000000` at 12% opacity.
  - Primary Buttons: elevation 4, tinted shadow matching `{colors.primary}` at 50% opacity.
  - Dialogs/Sheets: elevation 0 (relying on color contrasts and overlays instead of hard shadows).

## Components
- **Card**: Rounded to 16px, white background in light mode, margin of 8px vertical and 16px horizontal.
- **Primary Button**: Rounded to 16px, 16px vertical padding, navy background, white text.
- **Dialogs and Bottom Sheets**: Top-only border radius of 20px for bottom sheets, 16px all-around border radius for dialogs.

## Do's and Don'ts
### Do's
- Do maintain clear, readable text colors with >= 4.5:1 contrast against their card backgrounds.
- Do keep padding uniform (16px) inside cards and sheets.
- Do use `withValues(alpha: ...)` or similar transparent colors to create soft states rather than picking arbitrary hex values.

### Don't's
- Don't use nested card patterns (cards inside cards).
- Don't hardcode text colors directly inside list item content; use theme values.
- Don't use tight margins (<8px) between interactive elements.
