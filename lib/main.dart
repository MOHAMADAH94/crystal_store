import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/order_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp(
        title: 'Crystal Store',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,

          // الخط الافتراضي للتطبيق
          fontFamily: 'AlinmaSans',

          // ضمان تطبيق الخط على Material 3 بالكامل
          textTheme: Typography.material2021().black.apply(
            fontFamily: 'AlinmaSans',
          ),

          // White, Purple, Silver Color Scheme
          brightness: Brightness.light,
          primaryColor: const Color(0xFF7C3AED), // Purple
          scaffoldBackgroundColor: const Color(0xFFF9FAFB), // Light Silver

          colorScheme: const ColorScheme.light(
            primary: Color(0xFF7C3AED), // Purple
            secondary: Color(0xFF8B5CF6), // Light Purple
            tertiary: Color(0xFFA78BFA), // Lighter Purple
            surface: Colors.white,
            background: Color(0xFFF9FAFB), // Light Silver
            error: Color(0xFFEF4444),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Color(0xFF1F2937),
            onBackground: Color(0xFF1F2937),
            onError: Colors.white,
          ),

          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: Color(0xFF7C3AED), // Purple
            foregroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              fontFamily: 'AlinmaSans',
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          cardTheme: CardThemeData(
            elevation: 4,
            color: Colors.white,
            shadowColor: const Color(0xFF7C3AED).withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),

          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: Color(0xFF7C3AED), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            labelStyle: const TextStyle(color: Color(0xFF6B7280)),
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          ),

          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              elevation: 4,
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7C3AED),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          iconTheme: const IconThemeData(
            color: Color(0xFF7C3AED),
          ),

          dividerTheme: const DividerThemeData(
            color: Color(0xFFE5E7EB),
            thickness: 1,
          ),

          drawerTheme: const DrawerThemeData(
            backgroundColor: Color(0xFF7C3AED),
            elevation: 8,
            width: 280,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
