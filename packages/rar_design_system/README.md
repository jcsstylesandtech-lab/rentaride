# rar_design_system

The single source of truth for the Rent A Ride visual identity: premium blue
glassmorphism, Poppins typography, and reusable components.

```dart
import 'package:rar_design_system/rar_design_system.dart';

MaterialApp(theme: RarTheme.light(), darkTheme: RarTheme.dark());
```

| Token      | Value     | Use                                  |
|------------|-----------|--------------------------------------|
| `navy`     | `#061B49` | Primary / brand surfaces, dark bg    |
| `royal`    | `#0866FF` | Secondary / primary actions          |
| `cyan`     | `#00C8FF` | Accent / highlights                  |
| `white`    | `#FFFFFF` | Background, text on dark             |

Components: `GlassContainer`, `RarButton`, `RarLogo`, `RarWordmark`,
`FeatureTile`, `PillBadge`, `PageDots`, `IconTile`.
