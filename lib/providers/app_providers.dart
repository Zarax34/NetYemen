// lib/providers/app_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/network_model.dart';
import '../models/purchase_model.dart';
import '../models/payment_destination_model.dart';
import '../services/supabase_service.dart';

// Service
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

// Auth
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

// User Profile
final userProfileProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final service = ref.watch(supabaseServiceProvider);
  return await service.getUserProfile(user.id);
});

// Networks
final networksProvider = FutureProvider<List<Network>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.getNetworks();
});

final networksSearchQueryProvider = StateProvider<String>((ref) => '');

// Purchases
final userPurchasesProvider = FutureProvider<List<Purchase>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  return await service.getUserPurchases(user.id);
});

// Packages of a given network
final networkPackagesProvider =
    FutureProvider.family<List<NetworkPackage>, String>((ref, networkId) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.getNetworkPackages(networkId);
});

// Wallet
final walletLedgerProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  return await service.getWalletLedger(user.id);
});

final paymentDestinationsProvider =
    FutureProvider<List<PaymentDestination>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return await service.getPaymentDestinations();
});

final walletBalanceProvider = Provider<int>((ref) {
  final userAsync = ref.watch(userProfileProvider);
  return userAsync.when(
    data: (user) => user?.walletBalance ?? 0,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// UI State
final selectedTabProvider = StateProvider<int>((ref) => 0);
final selectedPackageIdProvider = StateProvider<String?>((ref) => null);

// Notifications
final notificationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final service = ref.watch(supabaseServiceProvider);
  return await service.listMyNotifications();
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  final service = ref.watch(supabaseServiceProvider);
  return await service.getUnreadNotificationCount();
});

final notificationPreferencesProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final service = ref.watch(supabaseServiceProvider);
  return await service.getNotificationPreferences();
});
