import 'package:flutter/material.dart';  // ✅ هذا هو الحل

class Wallet {
  final String id;
  final String name;
  final String type;
  final String? accountNumber;
  final bool isActive;
  final DateTime createdAt;

  Wallet({
    required this.id,
    required this.name,
    required this.type,
    this.accountNumber,
    this.isActive = true,
    required this.createdAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'bank',
      accountNumber: json['account_number']?.toString(),
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'account_number': accountNumber,
      'is_active': isActive,
    };
  }

  String get typeLabel {
    const types = {
      'bank': '🏦 بنك',
      'mobile': '📱 محفظة جوال',
      'crypto': '₿ عملات رقمية',
      'exchange': '💱 منصة تداول',
    };
    return types[type] ?? type;
  }

  Color get typeColor {
    const colors = {
      'bank': Colors.blue,
      'mobile': Colors.green,
      'crypto': Colors.orange,
      'exchange': Colors.purple,
    };
    return colors[type] ?? Colors.grey;
  }
}

class WalletsState {
  final List<Wallet> wallets;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  WalletsState({
    this.wallets = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  WalletsState copyWith({
    List<Wallet>? wallets,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return WalletsState(
      wallets: wallets ?? this.wallets,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<Wallet> get filteredWallets {
    if (searchQuery.isEmpty) return wallets;
    final query = searchQuery.toLowerCase();
    return wallets.where((w) {
      return w.name.toLowerCase().contains(query) ||
          w.type.toLowerCase().contains(query);
    }).toList();
  }
}