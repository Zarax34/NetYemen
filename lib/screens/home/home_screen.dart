// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/network_model.dart';
import '../../providers/app_providers.dart';
import '../../utils/app_theme.dart';
import 'network_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networksAsync = ref.watch(networksProvider);
    final searchQuery = ref.watch(networksSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NetYemen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                ref.read(networksSearchQueryProvider.notifier).state = value;
              },
              decoration: InputDecoration(
                hintText: 'ابحث عن شبكة...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          ref.read(networksSearchQueryProvider.notifier).state =
                              '';
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Networks List
          Expanded(
            child: networksAsync.when(
              data: (networks) {
                if (networks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 80,
                          color: AppTheme.border,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد شبكات متاحة',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: networks.length,
                  itemBuilder: (context, index) {
                    final network = networks[index];
                    return NetworkCard(network: network);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'حدث خطأ في تحميل الشبكات',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NetworkCard extends StatelessWidget {
  final Network network;

  const NetworkCard({super.key, required this.network});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NetworkDetailScreen(network: network),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  network.commercialName.isNotEmpty ? network.commercialName[0] : '?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            network.commercialName,
                            style: Theme.of(context).textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (network.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_user_rounded,
                            color: AppTheme.accent,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'موثّقة',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppTheme.accentDark,
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            network.locationText.isNotEmpty ? network.locationText : 'العنوان غير محدد',
                            style: Theme.of(context).textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
