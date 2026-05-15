import 'package:flutter/material.dart';
import '../../../features/auth/models/user_model.dart';
import '../../../features/auth/repositories/auth_repository.dart';

class ProfileViewModel extends ChangeNotifier {
  final AuthRepository _repo;

  ProfileViewModel(this._repo);

  bool _isSaving = false;
  String? _error;

  bool get isSaving => _isSaving;
  String? get error => _error;

  Future<bool> updateProfile(UserModel user) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.updateUser(user);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
