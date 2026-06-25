' tst_picocalc_pixel_fill.bas -- PIXEL FILL flood-fills a bounded area.
Option Explicit

Print "pixel_fill_start"
Cls
Box 0, 0, 10, 10, 1, Rgb(White)
Pixel Fill 5, 5, Rgb(Green)
If Pixel(5, 5) <> Rgb(Green) Then Error "PIXEL FILL did not fill interior"
If Pixel(20, 20) = Rgb(Green) Then Error "PIXEL FILL leaked outside boundary"
Print "pixel_fill_done"
