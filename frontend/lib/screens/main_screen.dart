import 'package:flutter/material.dart';
import 'package:ipay/screens/home/home_screen.dart';
import 'package:ipay/screens/scanner/barcode_scanner_screen.dart';
import 'package:ipay/screens/cart/cart_screen.dart';
import 'package:ipay/screens/orders/orders_screen.dart';
import 'package:ipay/screens/profile/profile_screen.dart';
import 'package:ipay/widgets/bottom_navigation_bar.dart';
import 'package:ipay/services/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int? _cartItemCount;

  List<Widget> get _screens => [
    HomeScreen(onNavigateToTab: _onNavItemTapped),
    const BarcodeScannerScreen(),
    const CartScreen(),
    const OrdersScreen(),
    const ProfileScreen(),
  ];
  
  final List<String> _screenNames = [
    'HomeScreen',
    'BarcodeScannerScreen', 
    'CartScreen',
    'OrdersScreen',
    'ProfileScreen',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground - only check login if it's been a while
        print('🔄 App resumed - checking login status');
        _checkLoginStatusIfNeeded();
        break;
      case AppLifecycleState.paused:
        // App went to background - no action needed
        print('⏸️ App paused');
        break;
      case AppLifecycleState.inactive:
        // App is inactive - no action needed
        break;
      case AppLifecycleState.detached:
        // App is detached - no action needed
        break;
      case AppLifecycleState.hidden:
        // App is hidden - no action needed
        break;
    }
  }

  // Check login status only if needed (not too frequently)
  Future<void> _checkLoginStatusIfNeeded() async {
    try {
      final authService = AuthService();
      final isLoggedIn = await authService.isLoggedIn();
      
      if (!isLoggedIn) {
        print('❌ User not logged in - redirecting to login');
        // User is not logged in, redirect to login
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      } else {
        print('✅ User is still logged in');
      }
    } catch (e) {
      print('Error checking login status: $e');
    }
  }

  Future<void> _checkLoginStatus() async {
    try {
      final authService = AuthService();
      final isLoggedIn = await authService.isLoggedIn();
      
      if (!isLoggedIn) {
        print('❌ User not logged in - redirecting to login');
        // User is not logged in, redirect to login
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      } else {
        print('✅ User is still logged in');
      }
    } catch (e) {
      print('Error checking login status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔧 MainScreen: Building with current index: $_currentIndex');
    print('🔧 MainScreen: Rendering screen: ${_screenNames[_currentIndex]} (${_screens[_currentIndex].runtimeType})');
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        cartItemCount: _cartItemCount,
        onTap: _onNavItemTapped,
        enableNavigation: true,
      ),
    );
  }

  void _onNavItemTapped(int index) {
    print('🔧 Bottom Nav: Tapped index $index, current index: $_currentIndex');
    print('🔧 Bottom Nav: Switching to ${_screenNames[index]}');
    setState(() {
      _currentIndex = index;
    });
    print('🔧 Bottom Nav: Updated current index to: $_currentIndex (${_screenNames[_currentIndex]})');
  }

  // Method to update cart count from child screens
  void updateCartCount(int count) {
    setState(() {
      _cartItemCount = count;
    });
  }
}
