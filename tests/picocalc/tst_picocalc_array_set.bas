Option Explicit
Option Base 1

Print "array_set_start"

Dim Float nums(3)
Dim Integer ints(3)
Dim String strs(3)
Dim Integer i%

nums(1) = 1.1 : nums(2) = 2.2 : nums(3) = 3.3
ints(1) = 1 : ints(2) = 2 : ints(3) = 3
strs(1) = "a" : strs(2) = "b" : strs(3) = "c"

Array Set 4.5, nums()
Array Set -7, ints()
Array Set "ok", strs()

For i% = 1 To 3
  If Abs(nums(i%) - 4.5) > 0.0001 Then Error "float array set failed"
  If ints(i%) <> -7 Then Error "integer array set failed"
  If strs(i%) <> "ok" Then Error "string array set failed"
Next i%

Print "array_set_done"
