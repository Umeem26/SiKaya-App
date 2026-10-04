import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'halaman_utama.dart';
import 'ui/komponen.dart';
import 'ui/tokens.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveAndStart() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('owner_name', _nameController.text.trim());

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HalamanUtama()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(color: Warna.primerMuda, shape: BoxShape.circle),
                  child: const Icon(Icons.store_mall_directory_rounded, size: 80, color: Warna.primer),
                ),
              ),
              const SizedBox(height: 32),
              Text("Halo, Juragan!", style: t.headlineMedium!.copyWith(color: Warna.primer)),
              const SizedBox(height: 8),
              Text(
                "Sebelum mulai mencatat, boleh tahu nama peternakan Kakak?",
                style: t.bodyLarge!.copyWith(color: Warna.teksSekunder),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                style: t.bodyLarge,
                decoration: const InputDecoration(
                  labelText: "Nama peternakan / pemilik",
                  hintText: "Contoh: Ternak Cibeusi Makmur",
                  prefixIcon: Icon(Icons.edit, color: Warna.aksenTeks),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Nama tidak boleh kosong ya" : null,
              ),
              const SizedBox(height: 32),
              TombolUtama(label: "Mulai mencatat", ikon: Icons.arrow_forward, onPressed: _saveAndStart),
            ],
          ),
        ),
      ),
    );
  }
}
