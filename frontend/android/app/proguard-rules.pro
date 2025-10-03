# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Razorpay rules
-keep class com.razorpay.** { *; }
-keep class proguard.annotation.Keep { *; }
-keep class proguard.annotation.KeepClassMembers { *; }
-keep @proguard.annotation.Keep class * { *; }
-keep @proguard.annotation.KeepClassMembers class * { *; }

# Keep Razorpay classes
-keep class com.razorpay.AnalyticsEvent { *; }
-keep class com.razorpay.** { *; }

# Keep all classes that might be referenced by Razorpay
-keep class * extends java.lang.Exception { *; }
-keep class * extends java.lang.Throwable { *; }

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all classes with @Keep annotation
-keep @androidx.annotation.Keep class * { *; }
-keep class * {
    @androidx.annotation.Keep *;
}

# Keep all classes with @KeepClassMembers annotation
-keepclassmembers @androidx.annotation.Keep class * { *; }

