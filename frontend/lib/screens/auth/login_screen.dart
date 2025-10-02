import 'package:flutter/material.dart';
import 'package:ipay/services/auth_service.dart';
import 'package:ipay/screens/auth/otp_verification_screen.dart';
import 'package:ipay/screens/main_screen.dart';
import 'package:iconsax/iconsax.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  
  // Phone authentication controllers
  final TextEditingController _phoneController = TextEditingController();
  bool _isPhoneLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _animationController.forward();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }


  void _handleSendOTP() async {
    if (_isPhoneLoading) return;
    
    final phoneNumber = _phoneController.text.trim();
    
    // Basic validation
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (phoneNumber.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Format phone number (add +91 if not present)
    String formattedPhone = phoneNumber;
    if (!phoneNumber.startsWith('+')) {
      formattedPhone = '+91$phoneNumber';
    }
    
    setState(() {
      _isPhoneLoading = true;
    });
    
    try {
      print('📱 Sending OTP to: $formattedPhone');
      
      final result = await _authService.sendPhoneOTP(formattedPhone);
      
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to OTP verification screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              phoneNumber: formattedPhone,
              verificationId: result.verificationId ?? formattedPhone,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send OTP: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isPhoneLoading = false;
      });
    }
  }

  void _handleGoogleSignIn() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      print('🚀 Starting Google Sign-In process...');
      
      // Test connection first
      print('🔄 Testing backend connection before Google Sign-In...');
      final connected = await _authService.testConnection();
      if (!connected) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot connect to backend server. Please check your connection.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
      
      final result = await _authService.signInWithGoogle();
      
      if (result.success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate based on result
        if (result.user != null) {
          if (result.isNewUser && result.showPhonePrompt) {
            // Show optional phone number setup dialog
            _showPhoneSetupDialog(result.user!);
          } else {
            // Navigate to home screen
            _navigateToHome(result.user!);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User data not available. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Sign-In failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPhoneSetupDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Phone Number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hi ${user['name']}!'),
              const SizedBox(height: 16),
              const Text(
                'Would you like to add your phone number for additional security and better shopping experience?',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToHome(user);
              },
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToPhoneSetup(user);
              },
              child: const Text('Add Phone'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToHome(Map<String, dynamic> user) {
    // Show welcome message briefly then navigate
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Welcome ${user['name']}!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Navigate to main screen and clear navigation stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
      (route) => false,
    );
  }

  void _testConnection() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Testing backend connection...'),
        backgroundColor: Colors.blue,
      ),
    );

    final connected = await _authService.testConnection();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(connected 
          ? '✅ Backend connection successful!' 
          : '❌ Backend connection failed. Check console for details.'),
        backgroundColor: connected ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }


  void _navigateToPhoneSetup(Map<String, dynamic> user) {
    // TODO: Navigate to phone setup screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Phone setup screen coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4A9B8E), // Darker teal at top
              Color(0xFF5BA8A0), // Medium teal
              Color(0xFF6BB5A7), // Lighter teal at bottom
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      // Top section with menu and logo
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              
                              // Menu icon (three dots)
                              Align(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    children: List.generate(3, (index) => Container(
                                      width: 4,
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    )),
                                  ),
                                ),
                              ),
                              
                              const Spacer(),
                              
                              // Logo section with circular background
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.2),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green,
                                    ),
                                    child: const Icon(
                                      Iconsax.shopping_cart,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Tagline
                              const Text(
                                'SMART SHOPPING IN YOUR HANDS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              
                              const SizedBox(height: 30),
                              
                              // App name
                              const Text(
                                'iPAY',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF9500), // Orange color
                                  letterSpacing: 2,
                                ),
                              ),
                              
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                      
                          // Bottom section with buttons
                      Expanded(
                        flex: 3,
                        child: Container(
                            width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Phone number input field
                                TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    hintText: 'Enter your phone number',
                                    prefixIcon: const Icon(
                                      Iconsax.call,
                                      color: Color(0xFF4A9B8E),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF4A9B8E),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Send OTP button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isPhoneLoading ? null : _handleSendOTP,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4A9B8E),
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shadowColor: Colors.black26,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    child: _isPhoneLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Send OTP',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // "or" text
                                Text(
                                  'or',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Connection Test Button (for debugging)
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: OutlinedButton(
                                    onPressed: _testConnection,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF4A9B8E)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text(
                                      'Test Backend Connection',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF4A9B8E),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                // Google Sign-In button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF5BA8A0),
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shadowColor: Colors.black26,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'Sign in using',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Center(
                                                  child: Text(
                                                    'G',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                    ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}