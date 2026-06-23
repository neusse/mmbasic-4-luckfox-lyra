' tst_picocalc_mminfo_calltable.bas -- MM.INFO(CALLTABLE) compatibility probe.
Option Explicit
Print "calltable_start"
Dim ct% = MM.INFO(CALLTABLE)
If ct% = 0 Then Error "missing calltable"
Print "calltable_done ct=";ct%
