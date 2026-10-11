import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'auth/login_screen.dart';
import 'auth/pin_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await Future.wait([
      authProvider.waitUntilReady(),
      Future.delayed(const Duration(seconds: 1)),
    ]);

    if (!mounted) return;

    final apiService = ApiService();

    // التحقق من الجلسة المحفوظة
    if (authProvider.userProfile == null && apiService.hasToken()) {
      await authProvider.loadProfile();
    }

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      // التحقق من وجود PIN
      try {
        final hasPin = await apiService.checkPinStatus();
        if (!mounted) return;
        
        if (!hasPin) {
          // إذا لم يكن هناك PIN، اطلب تعيينه
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PinScreen(isFirstTime: true)),
          );
        } else {
          // إذا كان هناك PIN، اطلب إدخاله
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PinScreen()),
          );
        }
      } catch (e) {
        // في حالة الخطأ، انتقل مباشرة للصفحة الرئيسية
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7C3AED), // Purple
              Color(0xFF8B5CF6), // Light Purple
              Color(0xFFA78BFA), // Lighter Purple
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/mylogo.png',
                  width: 350,
                  height: 350,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // إذا لم تكن الصورة موجودة، استخدم أيقونة افتراضية
                    return const Icon(
                      Icons.shopping_bag_rounded,
                      size: 100,
                      color: Colors.white,
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Crystal Store',
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 50),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
