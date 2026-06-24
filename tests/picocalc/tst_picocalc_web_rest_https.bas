' tst_picocalc_web_rest_https.bas -- Luckfox HTTPS REST smoke test.
Option Explicit

If MM.INFO$(ENVVAR "MMB4L_TEST_REST") <> "1" Then
  Print "picocalc_web_rest_https: NO ASSERTIONS - set MMB4L_TEST_REST=1 to run external HTTPS REST checks"
  End
EndIf

Dim response%(4096)
Dim status% = 0
Dim url$ = MM.INFO$(ENVVAR "MMB4L_TEST_REST_GET_URL")
If url$ = "" Then url$ = "https://example.com/"

WEB REST CLEAR HEADERS
WEB REST HEADER "Accept", "text/html, application/json"
WEB REST GET url$, response%(), status%, 20

If status% < 200 Or status% > 399 Then Error "GET status"
If LLen(response%()) <= 0 Then Error "GET empty response"

Dim postUrl$ = MM.INFO$(ENVVAR "MMB4L_TEST_REST_POST_URL")
If postUrl$ <> "" Then
  WEB REST CLEAR HEADERS
  WEB REST HEADER "X-MMB4L-Test", "picocalc"
  WEB REST POST postUrl$, "hello=picocalc", response%(), status%, "application/x-www-form-urlencoded", 20
  If status% < 200 Or status% > 399 Then Error "POST status"
  If LLen(response%()) <= 0 Then Error "POST empty response"
EndIf

Print "web_rest_https_done status="; status%; " bytes="; LLen(response%())
