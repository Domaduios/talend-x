# 🔧 حل مشكلة Java Version Error

## المشكلة:
```
Dependency requires at least JVM runtime version 11. 
This build uses a Java 8 JVM.
```

## الحل (اختر أحد الحلول):

### ✅ الحل الموصى به: تحديث Java إلى الإصدار 11 أو أحدث

#### Windows:
1. **حمّل Java 17 (LTS)** من: https://adoptium.net/
2. **ثبّت Java 17**
3. **حدّث متغيرات البيئة:**
   - افتح "Environment Variables" من Windows Search
   - أضف/حدّث `JAVA_HOME` إلى مسار Java 17 (مثلاً: `C:\Program Files\Eclipse Adoptium\jdk-17.x.x`)
   - أضف `%JAVA_HOME%\bin` إلى `PATH`
4. **أعد تشغيل Terminal/IDE**
5. **تحقق من الإصدار:**
   ```bash
   java -version
   ```
   يجب أن يظهر `version "17"` أو أعلى

#### بديل: استخدام Java المدمج في Android Studio
- إذا كان لديك Android Studio مثبت:
  - Android Studio يأتي مع JDK مدمج
  - يمكنك استخدامه من: `C:\Program Files\Android\Android Studio\jbr`

### ⚠️ حل مؤقت (غير موصى به): تقليل إصدار Gradle

إذا لم تستطع تحديث Java الآن، يمكنك تقليل إصدار Gradle:

1. **عدّل `android/gradle/wrapper/gradle-wrapper.properties`:**
   ```
   distributionUrl=https\://services.gradle.org/distributions/gradle-7.6.3-all.zip
   ```

2. **عدّل `android/settings.gradle.kts`:**
   ```kotlin
   id("com.android.application") version "7.4.2" apply false
   ```

3. **عدّل `android/app/build.gradle.kts`:**
   ```kotlin
   sourceCompatibility = JavaVersion.VERSION_1_8
   targetCompatibility = JavaVersion.VERSION_1_8
   jvmTarget = "1.8"
   ```

**ملاحظة:** هذا الحل قد يسبب مشاكل مع Flutter الحديث وبعض المكتبات.

---

## بعد التحديث:
1. **امسح مجلد `.gradle`** (اختياري):
   ```bash
   rm -rf android/.gradle
   rm -rf .gradle
   ```

2. **امسح Build Cache:**
   ```bash
   flutter clean
   ```

3. **أعد بناء المشروع:**
   ```bash
   flutter pub get
   flutter build apk
   ```

---

## للتحقق من Java الحالي:
```bash
java -version
javac -version
echo %JAVA_HOME%  # Windows
echo $JAVA_HOME   # Linux/Mac
```























