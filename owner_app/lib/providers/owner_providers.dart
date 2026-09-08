// lib/providers/owner_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/owned_network_model.dart';
import '../services/owner_supabase_service.dart';

// Service
final ownerServiceProvider = Provider<OwnerSupabaseService>((ref) {
  return OwnerSupabaseService();
});

// Auth
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

// Owned networks (حاجز الدور + محتوى لوحة التحكم)
final ownedNetworksProvider = FutureProvider<List<OwnedNetwork>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final service = ref.watch(ownerServiceProvider);
  return await service.getOwnedNetworks();
});

// شريط التنقل السفلي — الفهرس المختار
final selectedTabProvider = StateProvider<int>((ref) => 0);
