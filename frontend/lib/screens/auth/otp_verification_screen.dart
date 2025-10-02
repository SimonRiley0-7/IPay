import 'package:flutter/material.dart';
import 'package:ipay/services/auth_service.dart';
import 'package:ipay/screens/auth/registration_screen.dart';
import 'package:ipay/screens/home/home_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OTPVerificationScreen({
    Key? key,
    required this.phoneNumber,
    required this.verificationId,
  }) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOTP() async {
    if (_isLoading) return;

    final otp = _otpController.text.trim();
    
    if (otp.isEmpty || otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔍 Verifying OTP: $otp for phone: ${widget.phoneNumber}');
      
      final result = await _authService.verifyPhoneOTP(
        widget.verificationId,
        otp,
        widget.phoneNumber,
      );

      if (result.success) {
        print('✅ OTP verification successful!');
        print('📊 Full result object: $result');
        print('📊 requiresRegistration: ${result.requiresRegistration}');
        print('📊 isNewUser: ${result.isNewUser}');
        print('📊 user: ${result.user}');
        print('📊 phoneNumber: ${result.phoneNumber}');
        
        if (result.requiresRegistration == true) {
          print('🆕 NEW USER PATH: Navigating to registration screen');
          // New user - navigate to registration
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RegistrationScreen(
                phoneNumber: result.phoneNumber!,
              ),
            ),
          );
        } else {
          print('👤 EXISTING USER PATH: Navigating to home screen');
          print('🏠 About to call Navigator.pushAndRemoveUntil');
          
          // Existing user - navigate to home
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back ${result.user?['name']}!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Navigate to home screen
          try {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
            print('🏠 Navigation to HomeScreen completed');
          } catch (e) {
            print('❌ Navigation error: $e');
          }
        }
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
          content: Text('OTP verification failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resendOTP() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('📞 Resending OTP to: ${widget.phoneNumber}');
      
      final result = await _authService.sendPhoneOTP(widget.phoneNumber);
      
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP resent successfully!'),
            backgroundColor: Colors.green,
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
          content: Text('Failed to resend OTP: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
        backgroundColor: const Color(0xFF4A9B8E),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(
              Icons.sms,
              size: 80,
              color: Color(0xFF4A9B8E),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Enter Verification Code',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'We sent a 6-digit code to\n${widget.phoneNumber}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // OTP Input Field
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  letterSpacing: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4A9B8E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF4A9B8E),
                    width: 2,
                  ),
                ),
                counterText: '',
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Verify Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A9B8E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )
                    : const Text(
                        'Verify OTP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Resend OTP
            TextButton(
              onPressed: _resendOTP,
              child: const Text(
                'Didn\'t receive code? Resend',
                style: TextStyle(
                  color: Color(0xFF4A9B8E),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

