import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../repositories/document_repository.dart';
import '../services/doc_ai_service.dart';
import '../viewmodels/document_viewmodel.dart';

/// Shared provider scope for every screen under `/documents/...`, including
/// `DocumentsScreen`, `DocumentLibraryScreen`, `ScannerScreen`,
/// `ScannerEditorScreen`, `PdfViewerScreen`, `ImageToPdfScreen`,
/// `PdfGeneratorScreen` and `QrScreen`. Each route gets its own
/// `DocumentViewModel` instance.
class DocumentsScope extends StatelessWidget {
  final Widget child;
  const DocumentsScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return ChangeNotifierProvider<DocumentViewModel>(
      create: (_) => DocumentViewModel(
        repository: DocumentRepository(
          db: FirebaseFirestore.instance,
          userId: uid,
        ),
        aiService: DocAiService(
          groqApiKey: dotenv.env['GROQ_API_KEY'] ?? '',
        ),
      ),
      child: _DocumentsScopeGuard(child: child),
    );
  }
}

/// Stateful inner wrapper that:
/// 1. Holds a reference to the [DocumentViewModel] so it can be used safely
///    from [dispose] (where reading via Provider is no longer allowed).
/// 2. Intercepts system back / AppBar back navigation while a scan session is
///    in progress and confirms with the user before discarding pages.
/// 3. Clears any leftover scan session when the scope is torn down without
///    `finalizeScan` having run.
class _DocumentsScopeGuard extends StatefulWidget {
  final Widget child;
  const _DocumentsScopeGuard({required this.child});

  @override
  State<_DocumentsScopeGuard> createState() => _DocumentsScopeGuardState();
}

class _DocumentsScopeGuardState extends State<_DocumentsScopeGuard> {
  DocumentViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm ??= context.read<DocumentViewModel>();
  }

  @override
  void dispose() {
    final vm = _vm;
    if (vm != null && vm.processedPages.isNotEmpty) {
      vm.clearScanSession();
    }
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final vm = _vm;
    if (vm == null || vm.processedPages.isEmpty) return true;
    final discard = await _confirmDiscard();
    if (discard) {
      vm.clearScanSession();
      return true;
    }
    return false;
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.warning,
          size: 36,
        ),
        title: Text(
          'Discard scan?',
          style: AppTextStyles.h4,
          textAlign: TextAlign.center,
        ),
        content: Text(
          'You have an unsaved scan in progress. Going back will discard the '
          'captured pages.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Discard',
              style: AppTextStyles.body.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _onWillPop,
      child: widget.child,
    );
  }
}
