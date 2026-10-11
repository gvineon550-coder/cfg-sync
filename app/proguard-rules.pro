-keep class com.nova.sync.data.** { *; }
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.nova.sync.**$$serializer { *; }
-keepclassmembers class com.nova.sync.** { *** Companion; }
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}
-keep class com.nova.sync.NativeStrings { *; }
-keep class com.nova.sync.SignatureGuard { *; }
-dontwarn androidx.compose.**
-keep class com.nova.sync.App { *; }
-keep class com.nova.sync.MainActivity { *; }
