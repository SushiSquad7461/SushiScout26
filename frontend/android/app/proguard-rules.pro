# ProGuard rules for SushiScout 26
# These rules prevent code obfuscation from breaking Firebase, Drift, and other dependencies

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**

# Drift/SQLite
-keep class com.drift.** { *; }
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep constructors for serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Riverpod
-keep class * extends StateNotifier { *; }

# Don't obfuscate model classes (prevent Firebase/JSON serialization issues)
-keep class com.sushiscout.frontend.** { *; }
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}
