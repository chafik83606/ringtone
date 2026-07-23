import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/pro_service.dart';

class ProScreen extends StatelessWidget {
  const ProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final proService = context.watch<ProService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Version Pro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.deepPurple, Colors.indigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 48),
                  const SizedBox(height: 8),
                  const Text(
                    'Ringtone Maker Pro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Débloquez toutes les fonctionnalités',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Features list
            const Text(
              'Ce que vous obtenez',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...[
              (
                'Édition audio illimitée (jusqu\'à 10 min)',
                Icons.timer_outlined,
              ),
              ('Composition complète : 8×16 notes', Icons.piano),
              ('Export haute qualité (320 kbps)', Icons.high_quality),
              ('Fondu entrée / sortie', Icons.graphic_eq),
              ('Instruments Piano, Cloche et Sinus', Icons.library_music),
            ].map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(item.$2, color: Colors.deepPurple, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item.$1)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            if (!proService.storeAvailable)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'La boutique Google Play / App Store n\'est pas disponible '
                  'sur cet appareil.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              )
            else if (!proService.productsReady)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Produits Pro introuvables',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppConfig.isAndroid
                          ? 'Créez et activez ringtone_pro_monthly, '
                                'ringtone_pro_annual et ringtone_pro_lifetime '
                                'dans Google Play Console, puis installez l\'app '
                                'depuis le Play Store (test interne).'
                          : 'Créez les produits in-app dans App Store Connect '
                                'avec les mêmes identifiants, puis testez via TestFlight.',
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),

            // Abonnement mensuel
            _PriceCard(
              title: 'Abonnement mensuel',
              price: proService.monthlyPriceLabel,
              subtitle: '1,99 €/mois — annulable à tout moment',
              icon: Icons.calendar_view_month,
              color: Colors.indigo,
              isLoading: proService.isLoading,
              onTap: () async {
                final ok = await proService.purchasePro(ProPlan.monthly);
                if (!context.mounted) return;
                _showResult(context, ok);
              },
            ),
            const SizedBox(height: 12),

            // Abonnement annuel
            _PriceCard(
              title: 'Abonnement annuel',
              price: proService.annualPriceLabel,
              subtitle: '9,99 €/an — meilleur rapport qualité-prix',
              icon: Icons.event,
              color: Colors.teal,
              isLoading: proService.isLoading,
              onTap: () async {
                final ok = await proService.purchasePro(ProPlan.annual);
                if (!context.mounted) return;
                _showResult(context, ok);
              },
            ),
            const SizedBox(height: 12),

            // Achat à vie
            _PriceCard(
              title: 'Accès à vie',
              price: proService.lifetimePriceLabel,
              subtitle: '39,90 € — paiement unique',
              icon: Icons.all_inclusive,
              color: Colors.deepPurple,
              isLoading: proService.isLoading,
              onTap: () async {
                final ok = await proService.purchasePro(ProPlan.lifetime);
                if (!context.mounted) return;
                _showResult(context, ok);
              },
            ),

            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                final ok = await proService.restorePurchases();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Achats restaurés !'
                          : (proService.lastError ?? 'Aucun achat trouvé'),
                    ),
                  ),
                );
              },
              child: const Text('Restaurer mes achats'),
            ),

            const SizedBox(height: 16),
            const _SubscriptionLegalInfo(),

            const SizedBox(height: 8),
            Text(
              AppConfig.isAndroid
                  ? 'Les prix viennent de Google Play.\n'
                        'Abonnements : renouvellement automatique sauf annulation '
                        '24 h avant la fin de la période.'
                  : 'Les prix viennent de l\'App Store.\n'
                        'Abonnements : renouvellement automatique sauf annulation '
                        '24 h avant la fin de la période.',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showResult(BuildContext context, bool ok) {
    final proService = context.read<ProService>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Bienvenue dans la version Pro !'
              : (proService.lastError ?? 'Achat annulé ou échoué'),
        ),
        backgroundColor: ok ? Colors.green : null,
      ),
    );
    if (ok) Navigator.pop(context);
  }
}

class _SubscriptionLegalInfo extends StatelessWidget {
  const _SubscriptionLegalInfo();

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir : $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final proService = context.watch<ProService>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations sur les abonnements',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _LegalLine(
            title: 'Ringtone Maker Pro — Mensuel',
            detail:
                'Durée : 1 mois · Prix : ${proService.monthlyPriceLabel} · '
                'Renouvellement automatique.',
          ),
          const SizedBox(height: 6),
          _LegalLine(
            title: 'Ringtone Maker Pro — Annuel',
            detail:
                'Durée : 1 an · Prix : ${proService.annualPriceLabel} · '
                'Renouvellement automatique.',
          ),
          const SizedBox(height: 6),
          _LegalLine(
            title: 'Ringtone Maker Pro — Accès à vie',
            detail:
                'Achat unique · Prix : ${proService.lifetimePriceLabel} · '
                'Pas de renouvellement.',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () =>
                    _openUrl(context, AppConfig.privacyPolicyUrl),
                child: const Text('Politique de confidentialité'),
              ),
              TextButton(
                onPressed: () => _openUrl(context, AppConfig.termsOfUseUrl),
                child: const Text('Conditions d\'utilisation (EULA)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegalLine extends StatelessWidget {
  final String title;
  final String detail;

  const _LegalLine({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 11, color: Colors.grey.shade800, height: 1.4),
        children: [
          TextSpan(
            text: '$title\n',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: detail),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _PriceCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLoading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Column(
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
