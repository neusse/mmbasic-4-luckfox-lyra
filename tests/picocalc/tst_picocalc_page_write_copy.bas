' tst_picocalc_page_write_copy.bas -- PAGE WRITE/COPY work on the PicoCalc display.
Option Explicit

Print "page_write_copy_start"
Page Write 1
Cls
Pixel 0, 0, Rgb(Red)
Page Copy 1 To 0
Page Write 0
If Pixel(0, 0) <> Rgb(Red) Then Error "PAGE COPY did not update page 0"
Print "page_write_copy_done"
