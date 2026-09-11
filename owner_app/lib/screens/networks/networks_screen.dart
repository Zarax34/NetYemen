
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/owner_providers.dart';
import 'network_detail_screen.dart';

class NetworksScreen extends ConsumerWidget {
  const NetworksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networksAsyncValue = ref.watch(ownedNetworksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('شبكاتي')),
      body: networksAsyncValue.when(
        data: (networks) {
          if (networks.isEmpty) {
            return const Center(child: Text('لا توجد شبكات مسجلة.'));
          }
          return ListView.builder(
            itemCount: networks.length,
            itemBuilder: (context, index) {
              final network = networks[index];
              return ListTile(
                leading: const Icon(Icons.wifi),
                title: Text(network.commercialName),
                subtitle: Text('ID: ${network.id.substring(0, 8)}...'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NetworkDetailScreen(network: network),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('خطأ: $error')),
      ),
    );
  }
}
