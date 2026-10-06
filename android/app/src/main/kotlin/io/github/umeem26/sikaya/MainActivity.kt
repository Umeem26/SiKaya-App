package io.github.umeem26.sikaya

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 12+: splash sistem langsung dilepas (tanpa animasi pudar bawaan) saat
        // bingkai Flutter pertama siap. Bingkai itu identik dengan splash native (latar
        // biru, lingkaran logo 160dp di tengah), jadi peralihannya mulus dan animasi
        // splash Flutter (logo naik + tagline) tidak tertutup oleh animasi sistem.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { tampilan -> tampilan.remove() }
        }
    }
}
