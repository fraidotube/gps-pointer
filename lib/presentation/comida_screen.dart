import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../application/app_auth.dart';
import '../application/comida_service.dart';
import '../application/device_location_service.dart';

final class ComidaScreen extends StatefulWidget {
  const ComidaScreen({
    required this.locationService,
    required this.serverBaseUri,
    required this.authController,
    this.submittedBy,
    super.key,
  });

  final DeviceLocationService locationService;
  final Uri serverBaseUri;
  final AppAuthController authController;
  final String? submittedBy;

  @override
  State<ComidaScreen> createState() => _ComidaScreenState();
}

final class _ComidaScreenState extends State<ComidaScreen> {
  late final http.Client _client;
  late final ComidaService _service;
  DeviceLocationReading? _position;
  bool _readingPosition = false;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _service = ComidaService(
      _client,
      serverBaseUri: widget.serverBaseUri,
      authController: widget.authController,
    );
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<DeviceLocationReading?> _positionOrMessage() async {
    if (_position != null) return _position;
    if (_readingPosition) return null;
    setState(() => _readingPosition = true);
    try {
      final value = await widget.locationService.readCurrentPosition();
      if (!mounted) return value;
      setState(() => _position = value);
      return value;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Posizione non disponibile: $error')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _readingPosition = false);
    }
  }

  Future<void> _openNearby() async {
    final position = await _positionOrMessage();
    if (!mounted || position == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ComidaNearbyScreen(
          service: _service,
          position: position,
          locationService: widget.locationService,
        ),
      ),
    );
  }

  Future<void> _openRecommended() async {
    final position = await _positionOrMessage();
    if (!mounted || position == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ComidaRecommendedScreen(
          service: _service,
          position: position,
          locationService: widget.locationService,
        ),
      ),
    );
  }

  Future<void> _openAdd() async {
    final position = await _positionOrMessage();
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _ComidaEditorScreen(
          service: _service,
          locationService: widget.locationService,
          origin: position,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Comida')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 210, maxHeight: 105),
              child: Image.asset(
                'asset/comida_button.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Dove mangiare, scelto dalla community GPS Pointer',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 22),
          _HomeAction(
            icon: Icons.near_me_outlined,
            title: 'Cerca vicino a me',
            subtitle:
                'Locali GPS Pointer prima, poi OpenStreetMap. Raggio configurabile.',
            onTap: _readingPosition ? null : _openNearby,
          ),
          const SizedBox(height: 12),
          _HomeAction(
            icon: Icons.workspace_premium_outlined,
            title: 'Consigliati',
            subtitle:
                'Solo locali del database Comida, senza limite di distanza.',
            onTap: _readingPosition ? null : _openRecommended,
          ),
          const SizedBox(height: 12),
          _HomeAction(
            icon: Icons.add_location_alt_outlined,
            title: 'Aggiungi locale',
            subtitle:
                'GPS, ricerca per nome/indirizzo, link Maps o coordinate.',
            onTap: _readingPosition ? null : _openAdd,
          ),
          if (_readingPosition) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 24),
          const Text(
            'Un locale trovato su OSM può essere aggiunto a Comida e bollinato: '
            'da quel momento viene salvato sul server ed è visibile anche agli altri utenti.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

final class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(radius: 27, child: Icon(icon, size: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

final class _ComidaNearbyScreen extends StatefulWidget {
  const _ComidaNearbyScreen({
    required this.service,
    required this.position,
    required this.locationService,
  });

  final ComidaService service;
  final DeviceLocationReading position;
  final DeviceLocationService locationService;

  @override
  State<_ComidaNearbyScreen> createState() => _ComidaNearbyScreenState();
}

final class _ComidaNearbyScreenState extends State<_ComidaNearbyScreen> {
  late DeviceLocationReading _position;
  List<ComidaPlace> _places = const [];
  List<String> _warnings = const [];
  bool _loading = true;
  double _radiusKm = 10;
  String _category = 'Tutti';
  String _cuisine = 'Tutte';
  String _query = '';

  static const _radiusOptions = <double>[5, 10, 20, 30, 50];

  @override
  void initState() {
    super.initState();
    _position = widget.position;
    unawaited(_reload());
  }

  Future<void> _reload({bool refreshPosition = false}) async {
    if (mounted) setState(() => _loading = true);
    try {
      if (refreshPosition) {
        _position = await widget.locationService.readCurrentPosition();
      }
      final result = await widget.service.nearby(
        latitude: _position.latitude,
        longitude: _position.longitude,
        radiusKm: _radiusKm,
      );
      if (!mounted) return;
      setState(() {
        _places = result.places;
        _warnings = result.warnings;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _warnings = ['Ricerca non disponibile: $error']);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ComidaPlace> get _filtered {
    final query = _query.trim().toLowerCase();
    return _places
        .where((place) {
          if (_category != 'Tutti' && place.category != _category) return false;
          if (_cuisine != 'Tutte' &&
              !(place.cuisine ?? '')
                  .toLowerCase()
                  .split(',')
                  .map((e) => e.trim())
                  .contains(_cuisine.toLowerCase())) {
            return false;
          }
          if (query.isNotEmpty) {
            final haystack = [
              place.name,
              place.category,
              place.cuisine ?? '',
              place.address ?? '',
              place.review ?? '',
            ].join(' ').toLowerCase();
            if (!haystack.contains(query)) return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<String> get _categories {
    final values = _places.map((p) => p.category).toSet().toList()..sort();
    return ['Tutti', ...values];
  }

  List<String> get _cuisines {
    final values = <String>{};
    for (final place in _places) {
      for (final item in (place.cuisine ?? '').split(',')) {
        final value = item.trim();
        if (value.isNotEmpty) values.add(value);
      }
    }
    final sorted = values.toList()..sort();
    return ['Tutte', ...sorted];
  }

  Future<void> _editOrPromote(ComidaPlace place) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _ComidaEditorScreen(
          service: widget.service,
          locationService: widget.locationService,
          origin: _position,
          initialPlace: place,
        ),
      ),
    );
    if (changed == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comida · Vicino a me'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna posizione',
            onPressed: _loading ? null : () => _reload(refreshPosition: true),
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(),
          if (_warnings.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.amber.withValues(alpha: .12),
              child: Text(_warnings.join('\n')),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _loading && _places.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _reload(refreshPosition: true),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 28),
                      itemCount: filtered.length + 1,
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Dati esterni: © OpenStreetMap contributors · ODbL',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11),
                            ),
                          );
                        }
                        return _ComidaPlaceCard(
                          place: filtered[index],
                          onEditOrPromote: () =>
                              _editOrPromote(filtered[index]),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filters() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
    child: Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search),
            hintText: 'Nome, cucina, indirizzo…',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<double>(
                initialValue: _radiusKm,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Raggio',
                  border: OutlineInputBorder(),
                ),
                items: _radiusOptions
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('${value.toStringAsFixed(0)} km'),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value == null || value == _radiusKm) return;
                        setState(() => _radiusKm = value);
                        unawaited(_reload());
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _categories.contains(_category)
                    ? _category
                    : 'Tutti',
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _cuisines.contains(_cuisine) ? _cuisine : 'Tutte',
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Cucina',
            border: OutlineInputBorder(),
          ),
          items: _cuisines
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _cuisine = value);
          },
        ),
      ],
    ),
  );
}

final class _ComidaRecommendedScreen extends StatefulWidget {
  const _ComidaRecommendedScreen({
    required this.service,
    required this.position,
    required this.locationService,
  });

  final ComidaService service;
  final DeviceLocationReading position;
  final DeviceLocationService locationService;

  @override
  State<_ComidaRecommendedScreen> createState() =>
      _ComidaRecommendedScreenState();
}

final class _ComidaRecommendedScreenState
    extends State<_ComidaRecommendedScreen> {
  List<ComidaPlace> _places = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final places = await widget.service.recommended(
        latitude: widget.position.latitude,
        longitude: widget.position.longitude,
      );
      if (mounted) setState(() => _places = places);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(ComidaPlace place) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _ComidaEditorScreen(
          service: widget.service,
          locationService: widget.locationService,
          origin: widget.position,
          initialPlace: place,
        ),
      ),
    );
    if (changed == true) await _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Comida · Consigliati')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text('Server non disponibile: $_error'))
        : RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _places.length,
              itemBuilder: (context, index) => _ComidaPlaceCard(
                place: _places[index],
                onEditOrPromote: () => _edit(_places[index]),
              ),
            ),
          ),
  );
}

final class _ComidaPlaceCard extends StatelessWidget {
  const _ComidaPlaceCard({required this.place, required this.onEditOrPromote});

  final ComidaPlace place;
  final VoidCallback onEditOrPromote;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (place.badge != null) ...[
                Image.asset(
                  place.badge!.assetPath,
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      place.isGpsPointer ? 'GPS Pointer' : 'OpenStreetMap',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                _distance(place.distanceMeters),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _line('Tipologia', place.category),
          _line('Cucina', place.cuisine),
          _line('Prezzo', place.priceRange),
          _line('Orario', place.openingHours),
          _line('Indirizzo', place.address),
          _line('Telefono', place.phone),
          _line('Descrizione', place.review),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilledButton.tonalIcon(
                onPressed: onEditOrPromote,
                icon: Icon(
                  place.isGpsPointer
                      ? Icons.edit_outlined
                      : Icons.add_task_outlined,
                ),
                label: Text(
                  place.isGpsPointer ? 'MODIFICA' : 'AGGIUNGI A COMIDA',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openDirections(place),
                icon: const Icon(Icons.directions),
                label: const Text('INDICAZIONI'),
              ),
              if ((place.phone ?? '').trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('tel:${place.phone!.trim()}'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('CHIAMA'),
                ),
              if ((place.website ?? '').trim().isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openWebsite(place.website!),
                  icon: const Icon(Icons.public),
                  label: const Text('SITO'),
                ),
              OutlinedButton.icon(
                onPressed: () => _searchGoogle(place),
                icon: const Icon(Icons.search),
                label: const Text('CERCA SU GOOGLE'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  static Widget _line(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text('$label: ${value.trim()}'),
    );
  }

  static Future<void> _openDirections(ComidaPlace place) => launchUrl(
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${place.latitude},${place.longitude}',
    ),
    mode: LaunchMode.externalApplication,
  );

  static Future<void> _searchGoogle(ComidaPlace place) => launchUrl(
    Uri.https('www.google.com', '/search', {
      'q': [
        place.name,
        if ((place.address ?? '').trim().isNotEmpty) place.address!,
      ].join(' '),
    }),
    mode: LaunchMode.externalApplication,
  );

  static Future<void> _openWebsite(String value) async {
    final trimmed = value.trim();
    final uri = Uri.tryParse(
      trimmed.contains('://') ? trimmed : 'https://$trimmed',
    );
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

final class _ComidaEditorScreen extends StatefulWidget {
  const _ComidaEditorScreen({
    required this.service,
    required this.origin,
    this.locationService,
    this.initialPlace,
  });

  final ComidaService service;
  final DeviceLocationReading? origin;
  final DeviceLocationService? locationService;
  final ComidaPlace? initialPlace;

  @override
  State<_ComidaEditorScreen> createState() => _ComidaEditorScreenState();
}

final class _ComidaEditorScreenState extends State<_ComidaEditorScreen> {
  static const _categories = <String>[
    'Ristorante',
    'Pizzeria',
    'Trattoria',
    'Osteria',
    'Agriturismo',
    'Fast food',
    'Pub',
    'Bar / caffè',
    'Gelateria',
    'Pasticceria',
    'Paninoteca',
    'Sushi',
    'Altro',
  ];

  static const _cuisines = <String>[
    'Italiana',
    'Pizza',
    'Pesce',
    'Carne',
    'Vegetariana',
    'Vegana',
    'Asiatica',
    'Sushi',
    'Cinese',
    'Giapponese',
    'Messicana',
    'Indiana',
    'Mediterranea',
    'Hamburger',
    'Street food',
  ];

  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _website;
  late final TextEditingController _price;
  late final TextEditingController _review;
  late final TextEditingController _otherCuisine;
  late final TextEditingController _lat;
  late final TextEditingController _lon;
  late final TextEditingController _search;
  late final TextEditingController _mapsLink;
  late final TextEditingController _opening;
  late final TextEditingController _closing;

  late String _category;
  late ComidaBadge _badge;
  final Set<String> _selectedCuisines = {};
  List<ComidaGeocodeResult> _suggestions = const [];
  bool _busy = false;
  String? _positionStatus;

  @override
  void initState() {
    super.initState();
    final place = widget.initialPlace;
    _name = TextEditingController(text: place?.name ?? '');
    _address = TextEditingController(text: place?.address ?? '');
    _phone = TextEditingController(text: place?.phone ?? '');
    _website = TextEditingController(text: place?.website ?? '');
    _price = TextEditingController(text: _priceValue(place?.priceRange));
    _review = TextEditingController(text: place?.review ?? '');
    _otherCuisine = TextEditingController();
    _lat = TextEditingController(
      text:
          place?.latitude.toStringAsFixed(6) ??
          widget.origin?.latitude.toStringAsFixed(6) ??
          '',
    );
    _lon = TextEditingController(
      text:
          place?.longitude.toStringAsFixed(6) ??
          widget.origin?.longitude.toStringAsFixed(6) ??
          '',
    );
    _search = TextEditingController(text: place?.address ?? '');
    _mapsLink = TextEditingController();
    final hours = _parseHours(place?.openingHours);
    _opening = TextEditingController(text: hours.$1);
    _closing = TextEditingController(text: hours.$2);

    _category = _categories.contains(place?.category)
        ? place!.category
        : (place?.category ?? 'Ristorante');
    if (!_categories.contains(_category)) _category = 'Altro';
    _badge = place?.badge ?? ComidaBadge.bronze;

    for (final item in (place?.cuisine ?? '').split(',')) {
      final value = item.trim();
      if (value.isEmpty) continue;
      if (_cuisines.contains(value)) {
        _selectedCuisines.add(value);
      } else if (_otherCuisine.text.isEmpty) {
        _otherCuisine.text = value;
      }
    }

    if (_lat.text.isNotEmpty && _lon.text.isNotEmpty) {
      _positionStatus = place == null
          ? 'Posizione corrente precompilata.'
          : 'Posizione del locale caricata.';
    }
  }

  static String _priceValue(String? value) {
    if (value == null) return '';
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(value);
    return match?.group(0)?.replaceAll(',', '.') ?? '';
  }

  static (String, String) _parseHours(String? value) {
    final text = (value ?? '').trim();
    final both = RegExp(r'^(\d{2}:\d{2})-(\d{2}:\d{2})$').firstMatch(text);
    if (both != null) return (both.group(1)!, both.group(2)!);
    final opening = RegExp(r'^Apertura\s+(\d{2}:\d{2})$').firstMatch(text);
    if (opening != null) return (opening.group(1)!, '');
    final closing = RegExp(r'^Chiusura\s+(\d{2}:\d{2})$').firstMatch(text);
    if (closing != null) return ('', closing.group(1)!);
    return ('', '');
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _phone,
      _website,
      _price,
      _review,
      _otherCuisine,
      _lat,
      _lon,
      _search,
      _mapsLink,
      _opening,
      _closing,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _useCurrentPosition() async {
    final service = widget.locationService;
    if (service == null) return;
    await _guard(() async {
      final position = await service.readCurrentPosition();
      _setPosition(
        position.latitude,
        position.longitude,
        'Posizione GPS acquisita.',
      );
    });
  }

  Future<void> _searchPlace() async {
    await _guard(() async {
      final results = await widget.service.geocode(_search.text);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        if (results.isEmpty) _positionStatus = 'Nessun risultato trovato.';
      });
    });
  }

  Future<void> _resolveMaps() async {
    await _guard(() async {
      final position = await widget.service.resolveMapsLink(_mapsLink.text);
      _setPosition(
        position.latitude,
        position.longitude,
        'Coordinate ricavate dal link Maps.',
      );
    });
  }

  void _setPosition(double latitude, double longitude, String status) {
    if (!mounted) return;
    setState(() {
      _lat.text = latitude.toStringAsFixed(6);
      _lon.text = longitude.toStringAsFixed(6);
      _positionStatus = status;
      _suggestions = const [];
    });
  }

  Future<void> _guard(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _openingHours() {
    final opening = _opening.text.trim();
    final closing = _closing.text.trim();
    if (opening.isNotEmpty && closing.isNotEmpty) return '$opening-$closing';
    if (opening.isNotEmpty) return 'Apertura $opening';
    if (closing.isNotEmpty) return 'Chiusura $closing';
    return null;
  }

  String? _cuisineValue() {
    final values = _selectedCuisines.toList()..sort();
    final other = _otherCuisine.text.trim();
    if (other.isNotEmpty) values.add(other);
    return values.isEmpty ? null : values.join(', ');
  }

  Future<void> _save() async {
    final latitude = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final longitude = double.tryParse(_lon.text.trim().replaceAll(',', '.'));

    if (_name.text.trim().isEmpty) {
      _message('Inserisci il nome del locale.');
      return;
    }
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      _message(
        'Posizione non valida: usa GPS, ricerca, link Maps o coordinate.',
      );
      return;
    }

    final price = _price.text.trim().replaceAll(',', '.');
    if (price.isNotEmpty && double.tryParse(price) == null) {
      _message('Prezzo non valido.');
      return;
    }

    final place = widget.initialPlace;
    final draft = ComidaDraft(
      name: _name.text,
      category: _category,
      latitude: latitude,
      longitude: longitude,
      badge: _badge,
      sourceRef: place?.source == ComidaSource.openStreetMap
          ? (place!.sourceRef ?? place.id)
          : place?.sourceRef,
      cuisine: _cuisineValue(),
      address: _address.text,
      phone: _phone.text,
      website: _website.text,
      openingHours: _openingHours(),
      priceEuro: price.isEmpty ? null : '${price.replaceAll('.', ',')} €',
      review: _review.text,
    );

    await _guard(() async {
      final origin = widget.origin;
      final originLat = origin?.latitude ?? latitude;
      final originLon = origin?.longitude ?? longitude;

      if (place?.isGpsPointer == true && place?.serverId != null) {
        await widget.service.update(
          serverId: place!.serverId!,
          draft: draft,
          originLatitude: originLat,
          originLongitude: originLon,
        );
      } else {
        await widget.service.createOrPromote(
          draft: draft,
          originLatitude: originLat,
          originLongitude: originLon,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    });
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialPlace;
    final isPromotion = initial?.source == ComidaSource.openStreetMap;
    final isEdit = initial?.isGpsPointer == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit
              ? 'Modifica locale'
              : isPromotion
              ? 'Aggiungi a Comida'
              : 'Aggiungi locale',
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            if (isPromotion)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Questo locale arriva da OpenStreetMap. Salvandolo diventa '
                    'un locale del database Comida e sarà visibile a tutti.',
                  ),
                ),
              ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Tipologia',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 14),
            Text('Cucina', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _cuisines
                  .map(
                    (value) => FilterChip(
                      label: Text(value),
                      selected: _selectedCuisines.contains(value),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedCuisines.add(value);
                        } else {
                          _selectedCuisines.remove(value);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _otherCuisine,
              decoration: const InputDecoration(
                labelText: 'Altra cucina',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ComidaBadge>(
              initialValue: _badge,
              decoration: const InputDecoration(
                labelText: 'Bollino Comida',
                border: OutlineInputBorder(),
              ),
              items: ComidaBadge.values
                  .map(
                    (badge) => DropdownMenuItem(
                      value: badge,
                      child: Row(
                        children: [
                          Image.asset(
                            badge.assetPath,
                            width: 34,
                            height: 34,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          Text(badge.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _badge = value);
              },
            ),
            const SizedBox(height: 18),
            Text('Posizione', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (widget.locationService != null)
              FilledButton.tonalIcon(
                onPressed: _useCurrentPosition,
                icon: const Icon(Icons.my_location),
                label: const Text('QUI DOVE SONO'),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Nome locale / indirizzo / località',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Cerca',
                  onPressed: _searchPlace,
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) => _searchPlace(),
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              ..._suggestions.map(
                (item) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(item.displayName),
                    onTap: () {
                      _address.text = item.displayName;
                      if (_name.text.trim().isEmpty) {
                        _name.text = item.displayName.split(',').first.trim();
                      }
                      _setPosition(
                        item.latitude,
                        item.longitude,
                        'Risultato selezionato.',
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _mapsLink,
              decoration: InputDecoration(
                labelText: 'Link Google Maps',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Usa link',
                  onPressed: _resolveMaps,
                  icon: const Icon(Icons.link),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Indirizzo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lat,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Latitudine',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lon,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Longitudine',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_positionStatus != null) ...[
              const SizedBox(height: 6),
              Text(
                _positionStatus!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text('Dati locale', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefono',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _website,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Sito web',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Prezzo medio a persona (€)',
                hintText: 'es. 25',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _opening,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Apertura',
                      hintText: '09:00',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _closing,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Chiusura',
                      hintText: '23:00',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _review,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descrizione / nota',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                isEdit
                    ? 'SALVA SUL SERVER'
                    : isPromotion
                    ? 'AGGIUNGI A COMIDA'
                    : 'AGGIUNGI AL DATABASE',
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

String _distance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
}
