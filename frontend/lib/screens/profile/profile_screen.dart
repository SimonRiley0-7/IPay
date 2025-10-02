import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ipay/services/auth_service.dart';
import 'package:ipay/services/cloudinary_service.dart';
import 'package:ipay/services/cart_service.dart';
import 'package:ipay/services/wallet_service.dart';
import 'package:iconsax/iconsax.dart';
import 'package:ipay/screens/wallet/wallet_screen.dart';
import 'package:ipay/screens/orders/orders_screen.dart';
import 'package:ipay/screens/auth/login_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// Reuse the same theme from other screens
class AppTheme {
  static const Color primaryGreen = Color(0xFF4A9B8E);
  static const Color primaryGreenLight = Color(0xFF5BA8A0);
  static const Color primaryGreenDark = Color(0xFF3D8B8E);
  static const Color backgroundColor = Color(0xFFF8FFFE);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF1A202C);
  static const Color textSecondary = Color(0xFF718096);
  static const Color textTertiary = Color(0xFFA0AEC0);
  static const Color successColor = Color(0xFF38A169);
  static const Color errorColor = Color(0xFFE53E3E);
  static const Color warningColor = Color(0xFFD69E2E);
  
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 20.0;
  
  static const EdgeInsets paddingSmall = EdgeInsets.all(8.0);
  static const EdgeInsets paddingMedium = EdgeInsets.all(16.0);
  static const EdgeInsets paddingLarge = EdgeInsets.all(20.0);
  static const EdgeInsets paddingXLarge = EdgeInsets.all(24.0);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _imagePicker = ImagePicker();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // User data
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isUpdatingProfilePicture = false;
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  // Form state
  bool _isEmailVerified = false;
  bool _isPhoneVerified = false;
  bool _isSaving = false;
  
  // Phone verification states
  bool _isPhoneChanged = false;
  bool _isVerifyingPhone = false;
  bool _showOTPField = false;
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
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
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final userData = await _authService.getStoredUserData();
      
      if (userData != null) {
        setState(() {
          _userData = userData;
          _nameController.text = userData['name'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _phoneController.text = _removeCountryCode(userData['phone'] ?? '');
          _addressController.text = userData['address'] ?? '';
          _isEmailVerified = userData['emailVerified'] ?? false;
          _isPhoneVerified = userData['phoneVerified'] ?? false;
          _isPhoneChanged = false; // Reset phone change state
          _isLoading = false;
        });
        _animationController.forward();
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load user data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading profile: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showReLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Your session has expired. Please log in again to continue.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log In Again'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear App Data'),
        content: const Text('This will clear all stored data and log you out. You will need to log in again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear & Logout'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Helper method to format phone number with +91 prefix
  String _formatPhoneNumber(String phone) {
    if (phone.isEmpty) return phone;
    if (phone.startsWith('+')) return phone;
    return '+91$phone';
  }

  // Helper method to remove +91 prefix for display
  String _removeCountryCode(String phone) {
    if (phone.startsWith('+91')) {
      return phone.substring(3);
    }
    return phone;
  }

  void _onPhoneChanged(String value) {
    final originalPhone = _userData?['phone'] ?? '';
    final trimmedValue = value.trim();
    
    // Format the input value with +91 for comparison
    String formattedValue = _formatPhoneNumber(trimmedValue);
    
    setState(() {
      // Only show verification if phone is different from original AND not empty
      _isPhoneChanged = trimmedValue.isNotEmpty && formattedValue != originalPhone;
      _showOTPField = false; // Hide OTP field when phone changes
      
      // If user types the same number as original, reset verification state
      if (formattedValue == originalPhone) {
        _isPhoneVerified = _userData?['phoneVerified'] ?? false;
      }
    });
  }

  Future<void> _handleSaveProfile() async {
    if (_isSaving) return;
    
    // Check if phone number was changed but not verified
    final currentPhone = _phoneController.text.trim();
    final originalPhone = _userData?['phone'] ?? '';
    
    // Format current phone for comparison
    String formattedCurrentPhone = _formatPhoneNumber(currentPhone);
    
    final isPhoneActuallyChanged = currentPhone.isNotEmpty && formattedCurrentPhone != originalPhone;
    
    if (isPhoneActuallyChanged && !_isPhoneVerified) {
      _showErrorSnackBar('Please verify your new phone number before saving');
      return;
    }
    
    setState(() {
      _isSaving = true;
    });

    try {
      // Check if user is authenticated
      final isLoggedIn = await _authService.isLoggedIn();
      if (!isLoggedIn) {
        setState(() {
          _isSaving = false;
        });
        _showReLoginDialog();
        return;
      }

      // Skip token refresh for now - just try the profile update directly
      print('🔄 Attempting profile update...');

      // Format phone number with +91 if not already present
      String phoneNumber = _formatPhoneNumber(_phoneController.text.trim());
      
      final result = await _authService.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: phoneNumber,
        address: _addressController.text.trim(),
      );
      
      if (result.success) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
          _isPhoneChanged = false;
          _showOTPField = false;
          // Update local user data
          if (result.user != null) {
            _userData = result.user;
            _isEmailVerified = result.user!['emailVerified'] ?? false;
            _isPhoneVerified = result.user!['phoneVerified'] ?? false;
          }
        });
        
        _showSuccessSnackBar(result.message);
        HapticFeedback.lightImpact();
      } else {
        setState(() {
          _isSaving = false;
        });
        _showErrorSnackBar(result.message);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      _showErrorSnackBar('Failed to update profile: $e');
    }
  }

  void _handleEditToggle() {
    setState(() {
      _isEditing = !_isEditing;
    });
    HapticFeedback.lightImpact();
  }

  void _handleChangeProfilePicture() {
    HapticFeedback.lightImpact();
    _showImageSourceDialog();
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    'Change Profile Picture',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Options
                  Row(
                    children: [
                      // Camera option
                      Expanded(
                        child: _buildImageSourceOption(
                          icon: Iconsax.camera,
                          title: 'Camera',
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.camera);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Gallery option
                      Expanded(
                        child: _buildImageSourceOption(
                          icon: Iconsax.gallery,
                          title: 'Gallery',
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.gallery);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Remove option
                  if (_userData?['profilePicture'] != null && 
                      _userData!['profilePicture'].isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _removeProfilePicture();
                        },
                        icon: const Icon(
                          Iconsax.trash,
                          color: AppTheme.errorColor,
                          size: 20,
                        ),
                        label: const Text(
                          'Remove Picture',
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryGreen.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppTheme.primaryGreen,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        await _updateProfilePicture(File(image.path));
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _updateProfilePicture(File imageFile) async {
    try {
      setState(() {
        _isUpdatingProfilePicture = true;
      });

      // Upload image to Cloudinary
      final result = await _cloudinaryService.uploadProfilePicture(imageFile);
      
      if (result['success'] == true) {
        // Update local user data with server URL
        setState(() {
          _userData?['profilePicture'] = result['profilePicture'];
        });

        // Update the user data in AuthService
        await _authService.storeUserData(_userData!);

        _showSuccessSnackBar('Profile picture updated successfully!');
      } else {
        _showErrorSnackBar(result['message'] ?? 'Failed to update profile picture');
      }
    } catch (e) {
      print('Error updating profile picture: $e');
      _showErrorSnackBar('Failed to update profile picture: ${e.toString()}');
    } finally {
      setState(() {
        _isUpdatingProfilePicture = false;
      });
    }
  }

  Future<void> _removeProfilePicture() async {
    try {
      setState(() {
        _isUpdatingProfilePicture = true;
      });

      // Remove profile picture from Cloudinary
      final result = await _cloudinaryService.removeProfilePicture();
      
      if (result['success'] == true) {
        // Update local user data
        setState(() {
          _userData?['profilePicture'] = null;
        });

        // Update the user data in AuthService
        await _authService.storeUserData(_userData!);

        _showSuccessSnackBar('Profile picture removed successfully!');
      } else {
        _showErrorSnackBar(result['message'] ?? 'Failed to remove profile picture');
      }
    } catch (e) {
      print('Error removing profile picture: $e');
      _showErrorSnackBar('Failed to remove profile picture: ${e.toString()}');
    } finally {
      setState(() {
        _isUpdatingProfilePicture = false;
      });
    }
  }

  Future<void> _handleVerifyEmail() async {
    HapticFeedback.lightImpact();
    
    try {
      final result = await _authService.sendEmailVerification();
      
      if (result.success) {
        _showSuccessSnackBar(result.message);
      } else {
        _showErrorSnackBar(result.message);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to send verification email: $e');
    }
  }

  Future<void> _handleVerifyPhone() async {
    HapticFeedback.lightImpact();
    
    if (_isVerifyingPhone) return;
    
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      _showErrorSnackBar('Please enter a phone number first');
      return;
    }
    
    setState(() {
      _isVerifyingPhone = true;
    });
    
    try {
      // Format phone number (add +91 if not present)
      String formattedPhone = phoneNumber;
      if (!phoneNumber.startsWith('+')) {
        formattedPhone = '+91$phoneNumber';
      }
      
      final result = await _authService.sendPhoneOTP(formattedPhone);
      
      if (result.success) {
        setState(() {
          _showOTPField = true;
        });
        _showSuccessSnackBar('OTP sent to $formattedPhone');
      } else {
        _showErrorSnackBar(result.message);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to send verification OTP: $e');
    } finally {
      setState(() {
        _isVerifyingPhone = false;
      });
    }
  }

  Future<void> _verifyOTP() async {
    if (_isVerifyingPhone) return;
    
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length != 6) {
      _showErrorSnackBar('Please enter a valid 6-digit OTP');
      return;
    }
    
    setState(() {
      _isVerifyingPhone = true;
    });
    
    try {
      final phoneNumber = _phoneController.text.trim();
      String formattedPhone = phoneNumber;
      if (!phoneNumber.startsWith('+')) {
        formattedPhone = '+91$phoneNumber';
      }
      
      final result = await _authService.verifyPhoneOTP(
        formattedPhone, // verificationId
        otp,
        formattedPhone,
      );
      
      if (result.success) {
        setState(() {
          _isPhoneVerified = true;
          _isPhoneChanged = false;
          _showOTPField = false;
          _otpController.clear();
        });
        _showSuccessSnackBar('Phone number verified successfully!');
        HapticFeedback.lightImpact();
      } else {
        _showErrorSnackBar(result.message);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to verify OTP: $e');
    } finally {
      setState(() {
        _isVerifyingPhone = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: _isLoading 
            ? _buildLoadingState()
            : AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          _buildSliverAppBar(),
                          
                          SliverPadding(
                            padding: AppTheme.paddingLarge,
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                _buildProfileHeader(),
                                const SizedBox(height: 32),
                                _buildPersonalInfoSection(),
                                const SizedBox(height: 24),
                                _buildContactInfoSection(),
                                const SizedBox(height: 24),
                                _buildAddressSection(),
                                const SizedBox(height: 24),
                                _buildWalletSection(),
                                const SizedBox(height: 32),
                                 _buildActionButtons(),
                                 const SizedBox(height: 40), // Bottom padding
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
          ),
          SizedBox(height: 16),
          Text(
            'Loading profile...',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: const Icon(
                    Iconsax.arrow_left_2,
                    color: AppTheme.textPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
            
            // Title
            const Text(
              'Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            
            // Edit/Save button
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isEditing ? AppTheme.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isEditing ? _handleSaveProfile : _handleEditToggle,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          _isEditing ? Iconsax.tick_circle : Iconsax.edit,
                          color: _isEditing ? Colors.white : AppTheme.textPrimary,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: AppTheme.paddingXLarge,
        child: Column(
          children: [
            // Profile Picture
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryGreen.withOpacity(0.2),
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: _shouldShowProfileImage()
                        ? _isNetworkImage()
                            ? Image.network(
                                _userData!['profilePicture'], // Use original URL first
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return _buildLoadingAvatar();
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print('Profile image error: $error');
                                  // Try with Cloudinary optimization as fallback
                                  return Image.network(
                                    CloudinaryService.getThumbnailUrl(_userData!['profilePicture']),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      print('Cloudinary optimized image also failed: $error');
                                      return _buildDefaultAvatar();
                                    },
                                  );
                                },
                              )
                            : Image.file(
                                File(_userData!['profilePicture']),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultAvatar();
                                },
                              )
                        : _buildDefaultAvatar(),
                  ),
                ),
                if (_isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isUpdatingProfilePicture ? null : _handleChangeProfilePicture,
                          child: _isUpdatingProfilePicture
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Iconsax.camera,
                                  color: Colors.white,
                                  size: 16,
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Name
            Text(
              _userData?['name'] ?? 'User',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Member since
            Text(
              'Member since ${_getMemberSince()}',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSectionCard(
      title: 'Personal Information',
      icon: Iconsax.profile_circle,
      children: [
        _buildEditableField(
          label: 'Full Name',
          controller: _nameController,
          icon: Iconsax.user,
          enabled: _isEditing,
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return _buildSectionCard(
      title: 'Contact Information',
      icon: Iconsax.call,
      children: [
        _buildEditableField(
          label: 'Email Address',
          controller: _emailController,
          icon: Iconsax.sms,
          enabled: _isEditing,
          isVerified: _isEmailVerified,
          onVerify: _handleVerifyEmail,
        ),
        const SizedBox(height: 30),
        _buildEditableField(
          label: 'Phone Number',
          controller: _phoneController,
          icon: Iconsax.call,
          enabled: _isEditing,
          isVerified: _isPhoneVerified,
          onVerify: _isPhoneChanged ? _handleVerifyPhone : null,
          onChanged: _onPhoneChanged,
        ),
        
        // Show verify button if phone is changed but not verified
        if (_isPhoneChanged && !_isPhoneVerified) ...[
          const SizedBox(height: 16),
          _buildPhoneVerificationButton(),
        ],
        
        // Show OTP input field when verification is requested
        if (_showOTPField) ...[
          const SizedBox(height: 20),
          _buildOTPInputField(),
        ],
      ],
    );
  }

  Widget _buildAddressSection() {
    return _buildSectionCard(
      title: 'Address (Optional)',
      icon: Iconsax.location,
      children: [
        _buildEditableField(
          label: 'Address',
          controller: _addressController,
          icon: Iconsax.home_2,
          enabled: _isEditing,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildWalletSection() {
    return _buildSectionCard(
      title: 'Wallet & Orders',
      icon: Iconsax.wallet_3,
      children: [
        _buildWalletAction(
          icon: Iconsax.wallet_3,
          title: 'My Wallet',
          subtitle: 'Manage your wallet balance',
          onTap: _navigateToWallet,
        ),
        const SizedBox(height: 12),
        _buildWalletAction(
          icon: Iconsax.receipt_2,
          title: 'My Orders',
          subtitle: 'View your order history',
          onTap: _navigateToOrders,
        ),
      ],
    );
  }

  Widget _buildWalletAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          border: Border.all(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_right_2,
              color: AppTheme.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: AppTheme.paddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Section Content
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool enabled,
    bool isVerified = false,
    VoidCallback? onVerify,
    Function(String)? onChanged,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Iconsax.tick_circle,
                      color: AppTheme.successColor,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (onVerify != null && !isVerified) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onVerify,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Verify',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 8),
        
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: enabled ? AppTheme.primaryGreen : AppTheme.textTertiary,
              size: 20,
            ),
            filled: true,
            fillColor: enabled ? Colors.white : AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: enabled ? AppTheme.primaryGreen.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryGreen.withOpacity(0.3),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryGreen,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Logout Button
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.errorColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                _showLogoutDialog();
              },
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Iconsax.logout,
                      color: AppTheme.errorColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryGreen,
          ),
        ),
      );

      // Clear all user data
      await _authService.signOut();
      
      // Clear cart data
      try {
        final cartService = CartService();
        await cartService.clearCart();
      } catch (e) {
        print('Error clearing cart: $e');
      }
      
      // Clear wallet data
      try {
        final walletService = WalletService();
        await walletService.clearAllData();
      } catch (e) {
        print('Error clearing wallet data: $e');
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        _showErrorSnackBar('Logout failed: ${e.toString()}');
      }
    }
  }

  bool _shouldShowProfileImage() {
    return _userData?['profilePicture'] != null && 
           _userData!['profilePicture'].isNotEmpty;
  }

  bool _isNetworkImage() {
    return _userData?['profilePicture'] != null && 
           _userData!['profilePicture'].startsWith('http');
  }

  Widget _buildLoadingAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _userData?['name']?.split(' ').map((n) => n[0]).take(2).join() ?? 'U',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryGreen,
          ),
        ),
      ),
    );
  }

  String _getMemberSince() {
    if (_userData?['createdAt'] != null) {
      try {
        final date = DateTime.parse(_userData!['createdAt']);
        return '${date.month}/${date.year}';
      } catch (e) {
        return '2024';
      }
    }
    return '2024';
  }

  Widget _buildPhoneVerificationButton() {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isVerifyingPhone ? null : _handleVerifyPhone,
          child: Center(
            child: _isVerifyingPhone
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.call,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Send Verification OTP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildOTPInputField() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.security,
                color: AppTheme.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Enter Verification Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: TextStyle(
                color: AppTheme.textTertiary,
                letterSpacing: 2,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryGreen,
                  width: 2,
                ),
              ),
              counterText: '',
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isVerifyingPhone ? null : () {
                    setState(() {
                      _showOTPField = false;
                      _otpController.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGreen,
                        AppTheme.primaryGreen.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _isVerifyingPhone ? null : _verifyOTP,
                      child: Center(
                        child: _isVerifyingPhone
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Verify OTP',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToWallet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WalletScreen(),
      ),
    );
  }

  void _navigateToOrders() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const OrdersScreen(),
      ),
    );
  }
}
