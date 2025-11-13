# Preserve Singular SDK classes
-keep class com.singular.sdk.** { *; }

# Preserve Android Install Referrer library
-keep public class com.android.installreferrer.** { *; }

# Keep reflection-related code
-keepclassmembers class * {
    public *;
}

# Uncomment the following line if you are using the Singular 'revenue' function with Google Play Billing Library
#-keep public class com.android.billingclient.** { *; }

-keepattributes Signature
-keepattributes RuntimeVisibleAnnotations

# Retrofit support
-keep class retrofit2.** { *; }
-keep interface retrofit2.** { *; }

# Retrofit - keep generic type signatures and annotations
-keepattributes Signature
-keepattributes RuntimeVisibleAnnotations
-keepattributes MethodParameters

# Retrofit Call Adapters (if RxJava or Coroutines used internally)
-dontwarn retrofit2.adapter.rxjava2.**
-dontwarn retrofit2.adapter.rxjava3.**
-dontwarn retrofit2.adapter.kotlin.coroutines.**

# Moshi / Gson (if needed)
-keep class com.google.gson.** { *; }
-dontwarn com.squareup.moshi.**
-dontwarn com.google.gson.**

-keep class X7.** { *; }
-keep interface X7.** { *; }

# TrustArc SDK: don't obfuscate its classes (keeps Retrofit interfaces & models)
-keep class com.truste.androidmobileconsentsdk.** { *; }
-keep class com.trustarc.** { *; }

# Keep Retrofit interfaces and their method annotations (required for reflection)
-keepclasseswithmembers interface * { @retrofit2.http.* <methods>; }
-keepclasseswithmembers class * { @retrofit2.http.* <methods>; }

# OkHttp libs
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Preserve critical attributes so Retrofit can read generics/annotations
-keepattributes Signature, AnnotationDefault, RuntimeVisibleAnnotations, RuntimeInvisibleAnnotations, RuntimeVisibleParameterAnnotations, RuntimeInvisibleParameterAnnotations, MethodParameters, EnclosingMethod, InnerClasses, SourceFile, LineNumberTable

# ==============================================================================
# TEMPORARY FIX: Enhanced TrustArc SDK Retrofit ProGuard Rules
# To address generic type signature stripping issue in R8 full mode
# ==============================================================================

# Explicitly keep SDKService interface with all method signatures intact
-keep interface com.truste.androidmobileconsentsdk.tools.SDKService {
    *;
}

# Keep all TrustArc SDK tool interfaces with their methods
-keep interface com.truste.androidmobileconsentsdk.tools.** {
    *;
}

# Force preservation of Retrofit generic type information on TrustArc interfaces
-keepclassmembers,allowobfuscation interface com.truste.androidmobileconsentsdk.tools.** {
    @retrofit2.http.GET <methods>;
    @retrofit2.http.POST <methods>;
    @retrofit2.http.PUT <methods>;
    @retrofit2.http.DELETE <methods>;
    @retrofit2.http.PATCH <methods>;
}

# Prevent R8 from stripping Retrofit Call generic types
-keep,allowshrinking class retrofit2.Call { *; }
-keep,allowshrinking interface retrofit2.Call { *; }

# Keep SDK repository class that initializes Retrofit
-keep class com.truste.androidmobileconsentsdk.tools.SDKRepository {
    <init>(...);
    *;
}

# Ensure all SDK model classes are preserved with their fields for Gson deserialization
-keepclassmembers class com.truste.androidmobileconsentsdk.model.** {
    <init>();
    <init>(...);
    <fields>;
    *;
}

# Keep GetCountryResponse (the specific model failing in the error)
-keep class com.truste.androidmobileconsentsdk.model.GetCountryResponse { *; }
-keep class com.truste.androidmobileconsentsdk.model.GetConsentConfigsResponse { *; }

# Prevent stripping of method parameter names and annotations on SDK classes
-keepclassmembers class com.truste.androidmobileconsentsdk.** {
    @retrofit2.http.* <methods>;
}

# Keep Java Void class (used in Retrofit Call<Void> for submitMobileConsent)
-keep class java.lang.Void { *; }

# Additional protection for Retrofit's dynamic proxy mechanism
-keepclassmembers,allowshrinking interface * {
    @retrofit2.http.* <methods>;
}

# Ensure Retrofit can access Call.enqueue and Call.execute methods
-keepclassmembers interface retrofit2.Call {
    public ** enqueue(...);
    public ** execute(...);
    public ** clone();
}
