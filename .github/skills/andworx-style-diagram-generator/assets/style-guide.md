# Visio Engineering Drawing Style Guide for draw.io

This document defines the draw.io style properties that recreate the engineering drawing aesthetic from your Visio diagrams.

## Color Palette

| Element | Color | Hex |
|---------|-------|-----|
| Activity box border | Dark gray | `#333333` |
| Activity box fill | White | `#FFFFFF` |
| Activity box shadow | Light gray | `#F0F0F0` |
| Swim lane background | Light blue-gray | `#E8E8F0` |
| Grid/border | Dark gray | `#333333` |
| Text (primary) | Black | `#000000` |
| Text (labels) | Dark gray | `#555555` |
| Connector line | Dark gray | `#333333` |

## Shape Styles

### Activity Box (Rounded Rectangle)
```
rounded=1;shadow=1;strokeColor=#333333;fillColor=#FFFFFF;
strokeWidth=2;fontSize=11;fontFamily=Helvetica;
container=0;
```

### Start Event (Circle)
```
ellipse;shadow=1;strokeColor=#333333;fillColor=#FFFFFF;
strokeWidth=2;fontSize=10;fontFamily=Helvetica;
```

### End Event (Filled Double Circle)
```
ellipse;shadow=1;strokeColor=#333333;fillColor=#333333;
strokeWidth=2;fontSize=10;fontFamily=Helvetica;
```

### Swim Lane Header (Horizontal Container)
```
swimlane;fontStyle=0;childLayout=stackLayout;horizontal=1;
startSize=40;horizontalStack=0;resizeParent=1;
strokeColor=#333333;strokeWidth=1;fillColor=#E8E8F0;
fontSize=12;fontFamily=Helvetica;
```

### Swim Lane Label (Vertical Text)
```
text;html=1;strokeColor=none;fillColor=none;
fontSize=11;fontFamily=Helvetica;fontStyle=1;
rotation=-90;align=center;verticalAlign=middle;
```

### Connector Arrow
```
edgeStyle=orthogonalEdgeStyle;rounded=0;
orthogonalLoop=1;jettySize=auto;
html=1;strokeColor=#333333;strokeWidth=2;
exitX=1;exitY=0.5;entryX=0;entryY=0.5;
```

### Title Block Box
```
rounded=0;shadow=1;strokeColor=#333333;fillColor=#FFFFFF;
strokeWidth=1;fontSize=9;fontFamily=Helvetica;
```

### Engineering Border (Outer Frame)
```
rounded=0;shadow=0;strokeColor=#333333;fillColor=none;
strokeWidth=2;dashed=0;
```

## Layout Grid Reference

- **Page dimensions**: 1008 × 612 (16:9 landscape)
- **Engineering border margin**: 40 px
- **Row labels**: A, B, C, D (left edge, rotated 90°)
- **Column labels**: 4, 3, 2, 1 (top edge, right-to-left)
- **Title block position**: bottom-right, 400 × 80 px
- **Title block fields**: Title (left 50%), Version (middle 25%), Page (right 25%)
- **Swim lane width**: ~150 px each (5 lanes = ~750 px content area)

## Font Standards

- **Headers**: 12 pt, Bold, Helvetica
- **Activity labels**: 11 pt, Regular, Helvetica
- **Connector labels**: 10 pt, Regular, Helvetica
- **Row/column labels**: 10 pt, Bold, Helvetica

## Connector Routing

- **Style**: Orthogonal (right-angle bends, not diagonal)
- **Exit/Entry points**: Center of shape (0.5 on each axis)
- **Line weight**: 2 px
- **Arrowhead**: Filled triangle, size 10 px

## Shadow Effect

All primary shapes use `shadow=1` for depth. Shadow settings:
- X offset: 2 px
- Y offset: 2 px
- Opacity: 0.3
- Color: Automatic (darkens fill by ~20%)
