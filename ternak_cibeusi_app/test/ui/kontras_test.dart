// Tes 1 (S1): setiap pasangan teks/latar di token dan di ColorScheme tema
// berkontras minimal 4,5:1 (WCAG AA teks normal).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ternak_cibeusi_app/ui/theme.dart';
import 'package:ternak_cibeusi_app/ui/tokens.dart';

void main() {
  test('rumus kontras cocok dengan nilai acuan WCAG', () {
    expect(rasioKontras(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
    expect(rasioKontras(Warna.putih, Warna.putih), closeTo(1, 0.001));
    // Nilai di UI-PLAN.md (dihitung terpisah dengan Python).
    expect(rasioKontras(Warna.putih, Warna.primer), closeTo(7.77, 0.01));
    expect(rasioKontras(Warna.putih, const Color(0xFFFA9C1B)), closeTo(2.14, 0.01)); // oranye lama
  });

  test('semua pasangan token >= 4,5:1', () {
    final gagal = [
      for (final (nama, teks, latar) in pasanganKontras)
        if (rasioKontras(teks, latar) < 4.5) '$nama: ${rasioKontras(teks, latar).toStringAsFixed(2)}',
    ];
    expect(gagal, isEmpty, reason: 'pasangan di bawah 4,5:1');
    expect(pasanganKontras.length, greaterThanOrEqualTo(20));
  });

  test('pasangan on*/latar di ColorScheme tema >= 4,5:1', () {
    final s = temaSikaya().colorScheme;
    final pasangan = {
      'onPrimary/primary': (s.onPrimary, s.primary),
      'onPrimaryContainer/primaryContainer': (s.onPrimaryContainer, s.primaryContainer),
      'onSecondary/secondary': (s.onSecondary, s.secondary),
      'onTertiary/tertiary': (s.onTertiary, s.tertiary),
      'onError/error': (s.onError, s.error),
      'onErrorContainer/errorContainer': (s.onErrorContainer, s.errorContainer),
      'onSurface/surface': (s.onSurface, s.surface),
      'onSurfaceVariant/surface': (s.onSurfaceVariant, s.surface),
      'onSurface/scaffold': (s.onSurface, temaSikaya().scaffoldBackgroundColor),
    };
    for (final MapEntry(key: nama, value: (teks, latar)) in pasangan.entries) {
      expect(rasioKontras(teks, latar), greaterThanOrEqualTo(4.5), reason: nama);
    }
  });

  test('warna logo mentah tidak dipakai sebagai warna teks', () {
    // Dokumentasi: oranye koin hanya untuk isian; teks putih di atasnya gagal.
    expect(rasioKontras(Warna.putih, Warna.aksen), lessThan(4.5));
    expect(pasanganKontras.where((p) => p.$2 == Warna.aksen), isEmpty);
  });
}
