@ECHO OFF

:: Test if ruby is installed
WHERE ruby >NUL 2>NUL
IF %ERRORLEVEL% NEQ 0 ECHO Please install ruby and try again. & GOTO :EOF

@ECHO ON

gem install discordrb sqlite3 sequel httparty
