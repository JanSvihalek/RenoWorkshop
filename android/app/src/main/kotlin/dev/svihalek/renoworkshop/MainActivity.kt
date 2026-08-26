package dev.svihalek.renoworkshop

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (ne FlutterActivity) je podmínka pluginu local_auth -
// systémový dialog s otiskem je fragment a v čisté FlutterActivity spadne.
class MainActivity : FlutterFragmentActivity()
