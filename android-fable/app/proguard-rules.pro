# Minification is disabled for release in v1; keep serialization metadata for when it is enabled.
-keepattributes *Annotation*, InnerClasses
-dontwarn okhttp3.**
-dontwarn okio.**
-keep,includedescriptorclasses class app.mekasa.fable.**$$serializer { *; }
-keepclassmembers class app.mekasa.fable.** {
    *** Companion;
}
-keepclasseswithmembers class app.mekasa.fable.** {
    kotlinx.serialization.KSerializer serializer(...);
}
