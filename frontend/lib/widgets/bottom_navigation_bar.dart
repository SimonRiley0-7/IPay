import 'package:flutter/material.dart';
import 'package:ipay/services/cart_service.dart';
import 'package:iconsax/iconsax.dart';

// Reuse the same theme from home screen
class AppTheme {
  static const Color primaryGreen = Color(0xFF4A9B8E);
  static const Color primaryGreenLight = Color(0xFF5BA8A0);
  static const Color primaryGreenDark = Color(0xFF3D8B7E);
  static const Color backgroundColor = Color(0xFFF8FFFE);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF1A202C);
  static const Color textSecondary = Color(0xFF718096);
  static const Color textTertiary = Color(0xFFA0AEC0);
  static const Color successColor = Color(0xFF38A169);
  static const Color errorColor = Color(0xFFE53E3E);
  static const Color warningColor = Color(0xFFD69E2E);
}

class CustomBottomNavigationBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int? cartItemCount;
  final bool enableNavigation; // New parameter to control navigation behavior
  
  const CustomBottomNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.cartItemCount,
    this.enableNavigation = true, // Default to true for backward compatibility
  }) : super(key: key);

  @override
  State<CustomBottomNavigationBar> createState() => _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> {
  final CartService _cartService = CartService();
  int _cartItemCount = 0;
  bool _isLoadingCartCount = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _loadCartCount();
  }

  @override
  void didUpdateWidget(CustomBottomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update current index when widget updates
    if (widget.currentIndex != _currentIndex) {
      setState(() {
        _currentIndex = widget.currentIndex;
      });
    }
    
    // If cartItemCount is provided externally, use it; otherwise load from service
    if (widget.cartItemCount != null) {
      _cartItemCount = widget.cartItemCount!;
    } else if (oldWidget.cartItemCount != widget.cartItemCount) {
      _loadCartCount();
    }
  }

  Future<void> _loadCartCount() async {
    if (widget.cartItemCount != null) return; // Don't load if provided externally
    
    setState(() => _isLoadingCartCount = true);
    
    try {
      final count = await _cartService.getCartItemCount();
      if (mounted) {
        setState(() {
          _cartItemCount = count;
          _isLoadingCartCount = false;
        });
      }
    } catch (e) {
      print('Error loading cart count: $e');
      if (mounted) {
        setState(() => _isLoadingCartCount = false);
      }
    }
  }

  void _refreshCartCount() async {
    if (widget.cartItemCount != null) return; // Don't refresh if provided externally
    await _loadCartCount();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Iconsax.home_2,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Iconsax.scan,
                label: 'Scan',
                index: 1,
              ),
              _buildNavItem(
                icon: Iconsax.shopping_cart,
                label: 'Cart',
                index: 2,
              ),
              _buildNavItem(
                icon: Iconsax.receipt_2,
                label: 'Orders',
                index: 3,
              ),
              _buildNavItem(
                icon: Iconsax.profile_circle,
                label: 'Profile',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppTheme.primaryGreen : Colors.grey[600];
    final currentCartCount = widget.cartItemCount ?? _cartItemCount;
    
    print('🔧 Building nav item: $label (index: $index, isSelected: $isSelected, currentIndex: $_currentIndex)');

    return GestureDetector(
      onTap: () {
        print('🔧 Bottom Nav Item: Tapped $label (index: $index)');
        // Add haptic feedback for better UX
        if (index != _currentIndex) {
          // Only provide feedback when actually changing tabs
          // HapticFeedback.lightImpact(); // Uncomment if you want haptic feedback
        }
        // Directly call the parent's onTap callback - no NavigationHelper needed
        widget.onTap(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                if (index == 2 && currentCartCount > 0) // Cart tab with items
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        currentCartCount > 99 ? '99+' : '$currentCartCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                if (index == 2 && _isLoadingCartCount)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Public method to refresh cart count from parent widgets
  void refreshCartCount() {
    _refreshCartCount();
  }
}
