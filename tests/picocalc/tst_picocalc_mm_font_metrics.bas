' tst_picocalc_mm_font_metrics.bas -- MM.FONTWIDTH/HEIGHT aliases expose font metrics.
Option Explicit

Print "mm_font_metrics_start"

If MM.FONTWIDTH <> MM.INFO(FONTWIDTH) Then Error "MM.FONTWIDTH mismatch"
If MM.FONTHEIGHT <> MM.INFO(FONTHEIGHT) Then Error "MM.FONTHEIGHT mismatch"
If MM.FONTWIDTH <= 0 Then Error "MM.FONTWIDTH is not positive"
If MM.FONTHEIGHT <= 0 Then Error "MM.FONTHEIGHT is not positive"

Print "mm_font_metrics_done"
