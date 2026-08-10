# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Bluetooth serial plugin
-keep class io.github.edufolly.** { *; }

# Hive
-keep class * extends com.hivedb.** { *; }
-keepclassmembers class * {
    @hive.HiveField <fields>;
}
