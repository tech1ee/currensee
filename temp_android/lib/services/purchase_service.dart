import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../models/user_preferences.dart';

class PurchaseService with ChangeNotifier {
  final StorageService _storageService = StorageService();
  
  bool _isPremium = false;
  bool _isLoading = false;
  String? _error;
  
  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Initialize purchase service
  Future<void> initialize() async {
    try {
      final userPrefs = await _storageService.loadUserPreferences();
      _isPremium = userPrefs.isPremium;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load purchase status: $e';
      notifyListeners();
    }
  }
  
  // Purchase premium version
  Future<bool> purchasePremium() async {
    if (_isPremium) return true; // Already premium
    
    // Reset error state
    _error = null;
    
    // Set loading state
    _isLoading = true;
    notifyListeners();
    
    try {
      print('💲 PURCHASE SERVICE: Starting premium purchase');
      // In a real app, you would implement actual in-app purchase here
      // For now, we'll just simulate a purchase
      
      // Simulate API call - shorter time for better UX in demo
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Update premium status
      _isPremium = true;
      print('💲 PURCHASE SERVICE: Purchase successful');
      
      // Save to user preferences
      final userPrefs = await _storageService.loadUserPreferences();
      final updatedPrefs = userPrefs.copyWith(isPremium: true);
      await _storageService.saveUserPreferences(updatedPrefs);
      
      _isLoading = false;
      notifyListeners();
      return true;
      
    } catch (e) {
      print('💲 PURCHASE SERVICE: Purchase failed: $e');
      _error = 'Failed to complete purchase: $e';
      _isLoading = false;
      _isPremium = false; // Ensure this is set to false in case of error
      notifyListeners();
      return false;
    }
  }
  
  // Restore purchases
  Future<bool> restorePurchases() async {
    if (_isPremium) return true; // Already premium
    
    // Reset error state
    _error = null;
    
    // Set loading state
    _isLoading = true;
    notifyListeners();
    
    try {
      print('💲 PURCHASE SERVICE: Starting restore purchases');
      // In a real app, you would implement actual restore purchases here
      // For now, we'll just simulate the process
      
      // Simulate API call - shorter time for better UX in demo
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // For demo purposes, we'll just assume successful restoration
      _isPremium = true;
      print('💲 PURCHASE SERVICE: Restore successful');
      
      // Save to user preferences
      final userPrefs = await _storageService.loadUserPreferences();
      final updatedPrefs = userPrefs.copyWith(isPremium: true);
      await _storageService.saveUserPreferences(updatedPrefs);
      
      _isLoading = false;
      notifyListeners();
      return true;
      
    } catch (e) {
      print('💲 PURCHASE SERVICE: Restore failed: $e');
      _error = 'Failed to restore purchases: $e';
      _isLoading = false;
      _isPremium = false; // Ensure this is set to false in case of error
      notifyListeners();
      return false;
    }
  }
} 