Option Explicit
Print "save_image_start"
Const BASE$ = "/tmp/picocalc_save_image"
Const OUT$ = BASE$ + ".bmp"
On Error Skip 1
Kill OUT$
On Error Clear

CLS RGB(BLACK)
PIXEL 0, 0, RGB(RED)
PIXEL 1, 0, RGB(GREEN)
PIXEL 0, 1, RGB(BLUE)
SAVE IMAGE BASE$, 0, 0, 4, 4

If Not MM.Info(Exists OUT$) Then Error "save image file missing"
If MM.Info(FileSize OUT$) <= 54 Then Error "save image file too small"

Open OUT$ For Input As #1
Dim Sig$ = Input$(2, #1)
Close #1
If Sig$ <> "BM" Then Error "save image signature"

Print "save_image_done size="; MM.Info(FileSize OUT$); " hres="; MM.HRES; " vres="; MM.VRES
