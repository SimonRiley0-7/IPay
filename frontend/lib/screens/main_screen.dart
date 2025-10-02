import 'package:flutter/material.dart';
import 'package:ipay/screens/home/home_screen.dart';
import 'package:ipay/screens/scanner/barcode_scanner_screen.dart';
import 'package:ipay/screens/cart/cart_screen.dart';
import 'package:ipay/screens/orders/orders_screen.dart';
import 'package:ipay/screens/profile/profile_screen.dart';
import 'package:ipay/widgets/bottom_navigation_bar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
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
