# Project-specific R8 rules.

# Camera scanning depends on CameraX + ML Kit internals that are partly loaded
# through reflection/service discovery. Keep this path conservative so release
# minification does not break camera card scanning.
-keep class androidx.camera.** { *; }
-keep class androidx.camera.view.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.android.odml.** { *; }
-keep class com.google.firebase.components.** { *; }
-keep class com.google.firebase.encoders.** { *; }
-keep class com.google.android.datatransport.** { *; }
-keepnames class * extends com.google.mlkit.common.sdkinternal.ModelResource

-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
