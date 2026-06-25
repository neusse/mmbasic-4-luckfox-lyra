' tst_picocalc_play_sound_no_audio.bas -- PLAY SOUND should not abort when audio is unavailable.
Option Explicit

PLAY SOUND 1, B, N, 10, 10
PLAY STOP

Print "picocalc play sound no-audio fallback ok"
End
