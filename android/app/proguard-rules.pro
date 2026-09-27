# The Haxe -> Java runtime (haxe.lang.*) leans on reflection for field lookup and
# closures, and Android instantiates our classes by name from the manifest, so
# nothing here may be renamed or stripped. minifyEnabled is false by default; these
# rules exist so that turning R8 on stays safe.
-keep class haxe.** { *; }
-keep class java.** { *; }
-keep class phoenix.wallpaper.** { *; }
-keep class dev.phoenix.wallpaper.** { *; }
-keepclassmembers class phoenix.wallpaper.** { public *; }
-dontwarn haxe.**
-dontwarn java.**
