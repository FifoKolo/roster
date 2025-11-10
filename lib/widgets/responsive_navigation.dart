import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';
import '../theme/app_theme.dart';

/// Responsive navigation widget that adapts to device size and orientation
class ResponsiveNavigation extends StatelessWidget {
  final Widget child;
  final String title;
  final List<Widget> actions;
  final FloatingActionButton? floatingActionButton;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;

  const ResponsiveNavigation({
    Key? key,
    required this.child,
    required this.title,
    this.actions = const [],
    this.floatingActionButton,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(context),
      drawer: _shouldShowDrawer(context) ? drawer : null,
      endDrawer: endDrawer,
      bottomNavigationBar: _buildBottomNavigation(context),
      floatingActionButton: _buildFloatingActionButton(context),
      bottomSheet: bottomSheet,
      resizeToAvoidBottomInset: true,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final appBarHeight = ResponsiveHelper.getResponsiveAppBarHeight(context);
    final isLandscape = ResponsiveHelper.isLandscape(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return PreferredSize(
      preferredSize: Size.fromHeight(appBarHeight),
      child: AppBar(
        title: Text(
          title,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        elevation: isLandscape && isMobile ? 2 : 4,
        actions: _buildAppBarActions(context),
        iconTheme: IconThemeData(
          color: Colors.white,
          size: ResponsiveHelper.getResponsiveIconSize(context, 24),
        ),
        toolbarHeight: appBarHeight,
        automaticallyImplyLeading: _shouldShowDrawer(context),
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isLandscape = ResponsiveHelper.isLandscape(context);
    
    if (isMobile && isLandscape && actions.length > 2) {
      // In mobile landscape, show fewer actions to save space
      return [
        ...actions.take(1),
        PopupMenuButton<int>(
          icon: Icon(
            Icons.more_vert,
            size: ResponsiveHelper.getResponsiveIconSize(context, 24),
            color: Colors.white,
          ),
          onSelected: (index) {
            // Handle overflow menu actions
          },
          itemBuilder: (context) => List.generate(
            actions.length - 1,
            (index) => PopupMenuItem<int>(
              value: index + 1,
              child: Text('Action ${index + 2}'),
            ),
          ),
        ),
      ];
    }
    
    return actions;
  }

  Widget _buildBody(BuildContext context) {
    final padding = ResponsiveHelper.getResponsivePadding(context);
    final isLandscape = ResponsiveHelper.isLandscape(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    
    Widget body = child;
    
    // Add responsive padding
    if (isMobile) {
      body = Padding(
        padding: isLandscape 
          ? EdgeInsets.symmetric(horizontal: padding.horizontal / 2, vertical: padding.vertical)
          : padding,
        child: body,
      );
    }
    
    // Add safe area for mobile devices
    if (isMobile) {
      body = SafeArea(
        child: body,
        minimum: ResponsiveHelper.getResponsiveMargin(context),
      );
    }
    
    return body;
  }

  Widget? _buildBottomNavigation(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isPortrait = ResponsiveHelper.isPortrait(context);
    
    // Only show bottom navigation on mobile portrait mode if provided
    if (isMobile && isPortrait && bottomNavigationBar != null) {
      return bottomNavigationBar;
    }
    
    return null;
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    if (floatingActionButton == null) return null;
    
    final fabSize = ResponsiveHelper.getResponsiveFABSize(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    final isLandscape = ResponsiveHelper.isLandscape(context);
    
    // In mobile landscape, make FAB smaller and position it differently
    if (isMobile && isLandscape) {
      return SizedBox(
        width: fabSize,
        height: fabSize,
        child: FloatingActionButton(
          onPressed: (floatingActionButton as FloatingActionButton).onPressed,
          backgroundColor: AppTheme.primaryBlue,
          child: (floatingActionButton as FloatingActionButton).child,
          mini: true,
        ),
      );
    }
    
    return floatingActionButton;
  }

  bool _shouldShowDrawer(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    return drawer != null && isMobile;
  }
}

/// Responsive bottom sheet for mobile devices
class ResponsiveBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isScrollControlled = true,
    bool isDismissible = true,
  }) {
    final shouldUseBottomSheet = ResponsiveHelper.shouldUseBottomSheet(context);
    
    if (shouldUseBottomSheet) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        isDismissible: isDismissible,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => _BottomSheetContent(
          title: title,
          child: child,
        ),
      );
    } else {
      // Use dialog for larger screens
      return showDialog<T>(
        context: context,
        barrierDismissible: isDismissible,
        builder: (context) => Dialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveHelper.getResponsiveDialogWidth(context),
              maxHeight: ResponsiveHelper.getResponsiveDialogMaxHeight(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      );
    }
  }
}

class _BottomSheetContent extends StatelessWidget {
  final String? title;
  final Widget child;

  const _BottomSheetContent({
    Key? key,
    this.title,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.9;
    
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: AppTheme.textSecondary,
                      size: ResponsiveHelper.getResponsiveIconSize(context, 24),
                    ),
                  ),
                ],
              ),
            ),
          
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
          ),
          
          // Safe area for bottom
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}