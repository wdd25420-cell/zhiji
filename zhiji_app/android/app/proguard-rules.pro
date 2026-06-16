# Flutter ProGuard/R8 规则
# 保留 Flutter 引擎相关
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# 保留 drift/SQLite
-keep class com.zhiji.zhiji.** { *; }
-keep class sqlite3.** { *; }
-keep class org.sqlite.** { *; }

# 保留 Dio/OkHttp 网络库
-keepattributes Signature
-keepattributes *Annotation*
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# 通用保留
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Freezed / json_serializable 序列化
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
-keep class * implements java.io.Serializable
-dontwarn com.google.gson.**
