import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final Color? color;
  final bool showText;
  final String? text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final MainAxisAlignment alignment;

  const LogoWidget({
    Key? key,
    this.width,
    this.height,
    this.color,
    this.showText = true,
    this.text,
    this.fontSize,
    this.fontWeight,
    this.alignment = MainAxisAlignment.center,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        // Logo Image
        Image.asset(
          'assets/images/logo.png',
          width: width ?? 40,
          height: height ?? 40,
          color: color,
          errorBuilder: (context, error, stackTrace) {
            // Fallback if logo image doesn't exist
            return Container(
              width: width ?? 40,
              height: height ?? 40,
              decoration: BoxDecoration(
                color: color ?? Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.shopping_cart,
                color: Colors.white,
                size: (width ?? 40) * 0.6,
              ),
            );
          },
        ),
        
        // Logo Text (if enabled)
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            text ?? 'NEO CART',
            style: TextStyle(
              fontSize: fontSize ?? 24,
              fontWeight: fontWeight ?? FontWeight.bold,
              color: color ?? Theme.of(context).primaryColor,
            ),
          ),
        ],
      ],
    );
  }
}

// Specialized logo widgets for different use cases
class AppBarLogo extends StatelessWidget {
  const AppBarLogo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const LogoWidget(
      width: 32,
      height: 32,
      showText: false,
    );
  }
}

class SplashLogo extends StatelessWidget {
  const SplashLogo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const LogoWidget(
      width: 120,
      height: 120,
      fontSize: 32,
      fontWeight: FontWeight.w800,
    );
  }
}

class LoginLogo extends StatelessWidget {
  const LoginLogo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const LogoWidget(
      width: 80,
      height: 80,
      fontSize: 28,
      fontWeight: FontWeight.w700,
    );
  }
}

class SmallLogo extends StatelessWidget {
  const SmallLogo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const LogoWidget(
      width: 24,
      height: 24,
      showText: false,
    );
  }
}