import 'package:flutter/material.dart';

import '../application/catalogue_controller.dart';

final class AddRadioStationScreen extends StatefulWidget {
  const AddRadioStationScreen({required this.controller, super.key});

  final CatalogueController controller;

  @override
  State<AddRadioStationScreen> createState() => _AddRadioStationScreenState();
}

final class _AddRadioStationScreenState extends State<AddRadioStationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _terrain = TextEditingController();
  final _pole = TextEditingController(text: '0');

  bool _loadingPosition = false;
  bool _saving = false;
  String? _positionStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrentPosition());
  }

  @override
  void dispose() {
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _terrain.dispose();
    _pole.dispose();
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String? _required(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Campo obbligatorio.';
    if (text.length > 120) return 'Massimo 120 caratteri.';
    return null;
  }

  String? _coordinate(String? value, double minimum, double maximum) {
    final parsed = _number(value ?? '');
    if (parsed == null || !parsed.isFinite) return 'Numero non valido.';
    if (parsed < minimum || parsed > maximum) {
      return 'Valore ammesso: $minimum – $maximum.';
    }
    return null;
  }

  String? _optionalNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = _number(text);
    return parsed == null || !parsed.isFinite ? 'Numero non valido.' : null;
  }

  String? _nonNegative(String? value) {
    final parsed = _number(value ?? '');
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return 'Inserisci zero o un valore positivo.';
    }
    return null;
  }

  Future<void> _useCurrentPosition({bool force = false}) async {
    setState(() {
      _loadingPosition = true;
      _positionStatus = 'Acquisizione posizione corrente…';
    });

    var reading = widget.controller.catalogueFilterLocation;
    if (force || reading == null) {
      final acquired = await widget.controller.refreshCatalogueFilterPosition();
      if (!mounted) return;
      if (!acquired) {
        setState(() {
          _loadingPosition = false;
          _positionStatus =
              widget.controller.errorMessage ?? 'Posizione non acquisita.';
        });
        return;
      }
      reading = widget.controller.catalogueFilterLocation;
    }
    if (reading == null || !mounted) return;

    _latitude.text = reading.latitude.toStringAsFixed(7);
    _longitude.text = reading.longitude.toStringAsFixed(7);
    setState(() {
      _loadingPosition = false;
      _positionStatus =
          'GPS acquisito • ±${reading!.horizontalAccuracyMeters.toStringAsFixed(0)} m';
    });
  }

  Future<void> _save({required bool exportAfter}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.controller.addManualBeacon(
        name: _name.text.trim(),
        latitude: _number(_latitude.text)!,
        longitude: _number(_longitude.text)!,
        terrainElevationMeters: _terrain.text.trim().isEmpty
            ? null
            : _number(_terrain.text),
        poleHeightMeters: _number(_pole.text)!,
      );
      if (exportAfter) {
        await widget.controller.exportCatalogue();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exportAfter
                ? 'Postazione salvata e catalogo TXT esportato.'
                : 'Postazione salvata nel catalogo locale.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aggiungi Postazione Radio')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nuova postazione',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'L’ID univoco viene generato automaticamente. '
                      'Puoi usare il GPS del telefono oppure inserire le coordinate.',
                    ),
                    const SizedBox(height: 14),
                    FilledButton.tonalIcon(
                      onPressed: _loadingPosition || _saving
                          ? null
                          : () => _useCurrentPosition(force: true),
                      icon: _loadingPosition
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: const Text('USA POSIZIONE ATTUALE'),
                    ),
                    if (_positionStatus != null) ...[
                      const SizedBox(height: 8),
                      Text(_positionStatus!, textAlign: TextAlign.center),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Nome postazione',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Latitudine',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => _coordinate(value, -90, 90),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _longitude,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Longitudine',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => _coordinate(value, -180, 180),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _terrain,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Quota terreno (m) – facoltativa',
                        border: OutlineInputBorder(),
                        helperText:
                            'Se vuota potrà essere acquisita successivamente.',
                      ),
                      validator: _optionalNumber,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pole,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Altezza palo (m)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _nonNegative,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(exportAfter: false),
              icon: const Icon(Icons.save_outlined),
              label: const Text('SALVA POSTAZIONE'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _save(exportAfter: true),
              icon: const Icon(Icons.ios_share_outlined),
              label: const Text('SALVA + ESPORTA CATALOGO TXT'),
            ),
          ],
        ),
      ),
    ),
  );
}
