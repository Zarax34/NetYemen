import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/owned_network_model.dart';
import '../../providers/networks_providers.dart';
import 'package_form_screen.dart';

class NetworkDetailScreen extends ConsumerStatefulWidget {
  final OwnedNetwork network;

  const NetworkDetailScreen({super.key, required this.network});

  @override
  ConsumerState<NetworkDetailScreen> createState() => _NetworkDetailScreenState();
}

class _NetworkDetailScreenState extends ConsumerState<NetworkDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddSsidDialog(BuildContext context) {
    final displayController = TextEditingController();
    final normalizedController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة SSID للشبكة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: displayController,
                decoration: const InputDecoration(labelText: 'اسم الشبكة (Display)'),
              ),
              TextField(
                controller: normalizedController,
                decoration: const InputDecoration(labelText: 'الاسم الموحد (Normalized)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final display = displayController.text.trim();
                final normalized = normalizedController.text.trim();
                if (display.isEmpty || normalized.isEmpty) return;
                
                try {
                  await ref.read(networksServiceProvider).createSsidAlias(
                    widget.network.id, display, normalized
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ref.invalidate(networkSsidAliasesProvider(widget.network.id));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e')),
                    );
                  }
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.network.commercialName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الباقات'),
            Tab(text: 'SSID Aliases'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Packages Tab
          _buildPackagesTab(),
          // SSID Aliases Tab
          _buildSsidTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PackageFormScreen(networkId: widget.network.id),
              ),
            ).then((_) {
              ref.invalidate(networkPackagesProvider(widget.network.id));
            });
          } else {
            _showAddSsidDialog(context);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPackagesTab() {
    final packagesAsync = ref.watch(networkPackagesProvider(widget.network.id));

    return packagesAsync.when(
      data: (packages) {
        if (packages.isEmpty) {
          return const Center(child: Text('لا توجد باقات لهذه الشبكة.'));
        }
        return ListView.builder(
          itemCount: packages.length,
          itemBuilder: (context, index) {
            final pkg = packages[index];
            return ListTile(
              title: Text(pkg['name']),
              subtitle: Text('${pkg['price']} YER - ${pkg['package_type']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pkg['status'] == 'draft')
                    IconButton(
                      icon: const Icon(Icons.publish, color: Colors.green),
                      onPressed: () async {
                        try {
                          await ref.read(networksServiceProvider).publishNetworkPackage(pkg['id']);
                          ref.invalidate(networkPackagesProvider(widget.network.id));
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                          }
                        }
                      },
                    ),
                  if (pkg['status'] == 'active')
                    IconButton(
                      icon: const Icon(Icons.block, color: Colors.red),
                      onPressed: () async {
                        try {
                          await ref.read(networksServiceProvider).deactivateNetworkPackage(pkg['id']);
                          ref.invalidate(networkPackagesProvider(widget.network.id));
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                          }
                        }
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PackageFormScreen(
                            networkId: widget.network.id,
                            packageData: pkg,
                          ),
                        ),
                      ).then((_) {
                        ref.invalidate(networkPackagesProvider(widget.network.id));
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('خطأ: $e')),
    );
  }

  Widget _buildSsidTab() {
    final ssidsAsync = ref.watch(networkSsidAliasesProvider(widget.network.id));

    return ssidsAsync.when(
      data: (ssids) {
        if (ssids.isEmpty) {
          return const Center(child: Text('لا توجد SSID aliases لهذه الشبكة.'));
        }
        return ListView.builder(
          itemCount: ssids.length,
          itemBuilder: (context, index) {
            final ssid = ssids[index];
            return ListTile(
              title: Text(ssid['ssid_display']),
              subtitle: Text('Status: ${ssid['status']} | Normalized: ${ssid['ssid_normalized']}'),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('خطأ: $e')),
    );
  }
}
