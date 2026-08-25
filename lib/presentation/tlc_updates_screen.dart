import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/app_auth.dart';
import '../application/tlc_feed_service.dart';

final class TlcUpdatesScreen extends StatefulWidget {
  const TlcUpdatesScreen({
    required this.serverBaseUri,
    required this.authController,
    super.key,
  });

  final Uri serverBaseUri;
  final AppAuthController authController;

  @override
  State<TlcUpdatesScreen> createState() => _TlcUpdatesScreenState();
}

final class _TlcUpdatesScreenState extends State<TlcUpdatesScreen> {
  late final TlcFeedService _service;
  TlcFeedResult? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = TlcFeedService(
      serverBaseUri: widget.serverBaseUri,
      authController: widget.authController,
    );
    _reload();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await _service.fetch();
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.article_outlined), text: 'NEWS'),
            Tab(icon: Icon(Icons.play_circle_outline), text: 'VIDEO'),
          ],
        ),
      ),
      body: _buildBody(context),
    ),
  );

  Widget _buildBody(BuildContext context) {
    if (_loading && _result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _result == null) {
      return _ErrorState(message: _error!, onRetry: _reload);
    }

    final result =
        _result ?? const TlcFeedResult(news: [], videos: [], warnings: []);
    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          _InfoBanner(icon: Icons.warning_amber_rounded, text: _error!),
        if (result.warnings.isNotEmpty)
          _InfoBanner(
            icon: Icons.info_outline,
            text:
                '${result.warnings.length} fonte/i temporaneamente non disponibili.',
          ),
        Expanded(
          child: TabBarView(
            children: [
              _FeedList(
                items: result.news,
                emptyText: 'Nessuna news TLC disponibile.',
                onRefresh: _reload,
              ),
              _FeedList(
                items: result.videos,
                emptyText: 'Nessun canale YouTube configurato o nessun video.',
                onRefresh: _reload,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _FeedList extends StatelessWidget {
  const _FeedList({
    required this.items,
    required this.emptyText,
    required this.onRefresh,
  });

  final List<TlcFeedItem> items;
  final String emptyText;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * .24),
            Icon(
              Icons.dynamic_feed_outlined,
              size: 54,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Center(child: Text(emptyText)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _FeedCard(item: items[index]),
      ),
    );
  }
}

final class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});

  final TlcFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isVideo = item.kind == 'video';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(item.url),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _ImageFallback(isVideo: isVideo),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isVideo
                            ? Icons.play_circle_outline
                            : Icons.article_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          item.channel ?? item.source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (item.publishedAt != null)
                        Text(
                          _formatDate(item.publishedAt!.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (!isVideo && item.summary.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      item.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        isVideo ? 'APRI IN YOUTUBE' : 'LEGGI ARTICOLO',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .6,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.open_in_new_rounded, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year}';

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

final class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF071E2A),
    child: Center(
      child: Icon(
        isVideo ? Icons.play_circle_outline : Icons.article_outlined,
        size: 54,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

final class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF2E6D89)),
      borderRadius: BorderRadius.circular(12),
      color: const Color(0xFF071E2A),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

final class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 54),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('RIPROVA'),
          ),
        ],
      ),
    ),
  );
}
