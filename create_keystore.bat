@echo off
echo ========================================
echo Creating Android Release Keystore
echo ========================================
echo.
echo This will create a keystore file for signing your app.
echo You will be asked several questions. Please answer carefully.
echo.
echo IMPORTANT: Save the passwords you enter - you'll need them!
echo.
pause

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

echo.
echo ========================================
echo Keystore created successfully!
echo ========================================
echo.
echo The file 'upload-keystore.jks' has been created.
echo.
echo NEXT STEPS:
echo 1. Move this file to a secure location (NOT in your project folder)
echo 2. Create key.properties file (instructions will follow)
echo 3. NEVER commit the keystore or key.properties to Git!
echo.
pause
