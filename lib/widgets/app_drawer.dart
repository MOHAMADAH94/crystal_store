import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/balance_history_screen.dart';
import '../screens/payment/send_money_screen.dart';
import '../screens/pages/about_screen.dart';
import '../screens/pages/terms_screen.dart';
import '../screens/notifications/notifications_screen.dart';

class AppDrawer extends StatefulWidget {
  final int? selectedIndex;
  final Function(int)? onItemSelected;

  const AppDrawer({super.key, this.selectedIndex, this.onItemSelected});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  bool _userSectionExpanded = false;

  String _formatBalance(double balance, String currency, double exchangeRate) {
    if (currency == 'SYP') {
      final convertedBalance = balance * exchangeRate;
      return '${convertedBalance.toStringAsFixed(2)} SYP';
    } else {
      return '\$${balance.toStringAsFixed(4)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // White, Purple, Silver Color Scheme with Gradients
    const Color purple = Color(0xFF7C3AED);
    const Color lightPurple = Color(0xFF8B5CF6);
    const Color lighterPurple = Color(0xFFA78BFA);
    const Color white = Colors.white;

    return Drawer(
      width: 280,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              purple, // Purple
              lightPurple, // Light Purple
              lighterPurple, // Lighter Purple
            ],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: white.withOpacity(0.2), width: 1),
                ),
                color: Colors.black.withOpacity(0.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo and Brand
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_rounded,
                              color: white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'CRYSTAL STORE',
                            style: TextStyle(
                              color: white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // User Balance Info (if authenticated)
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      if (authProvider.isAuthenticated &&
                          authProvider.userProfile == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          await authProvider.loadProfile();
                        });
                        return const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: const Text(
                            'جاري التحميل...',
                            style: TextStyle(color: white, fontSize: 12),
                          ),
                        );
                      }

                      if (authProvider.isAuthenticated &&
                          authProvider.userProfile != null) {
                        return Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'الرصيد:',
                                    style: TextStyle(
                                      color: white,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _formatBalance(
                                        authProvider.userProfile!.balance,
                                        authProvider.userProfile!.currency,
                                        authProvider.exchangeRate,
                                      ),
                                      style: const TextStyle(
                                        color: white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'المستوى:',
                                    style: TextStyle(
                                      color: white,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      authProvider.userProfile!.level
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Home
                  _DrawerItem(
                    icon: Icons.home,
                    label: 'الرئيسية',
                    isSelected: widget.selectedIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.onItemSelected != null) {
                        widget.onItemSelected!(0);
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        );
                      }
                    },
                    accentCyan: white,
                    textPrimary: white,
                  ),
                  // Packages
                  _DrawerItem(
                    icon: Icons.inventory_2_rounded,
                    label: 'الباقات',
                    isSelected: widget.selectedIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.onItemSelected != null) {
                        widget.onItemSelected!(0);
                      } else {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        );
                      }
                    },
                    accentCyan: white,
                    textPrimary: white,
                  ),
                  // User Section Dropdown
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      return ExpansionTile(
                        leading: Icon(
                          authProvider.isAuthenticated
                              ? Icons.person_rounded
                              : Icons.login_rounded,
                          color:
                              _userSectionExpanded ||
                                      widget.selectedIndex == 2 ||
                                      widget.selectedIndex == 3 ||
                                      widget.selectedIndex == 4 ||
                                      widget.selectedIndex == 8
                                  ? white
                                  : white.withOpacity(0.7),
                          size: 20,
                        ),
                        title: Text(
                          authProvider.isAuthenticated
                              ? 'الأقسام'
                              : 'تسجيل الدخول',
                          style: TextStyle(
                            color:
                                _userSectionExpanded ||
                                        widget.selectedIndex == 2 ||
                                        widget.selectedIndex == 3 ||
                                        widget.selectedIndex == 4 ||
                                        widget.selectedIndex == 8
                                    ? white
                                    : white.withOpacity(0.9),
                            fontWeight:
                                _userSectionExpanded ||
                                        widget.selectedIndex == 2 ||
                                        widget.selectedIndex == 3 ||
                                        widget.selectedIndex == 4 ||
                                        widget.selectedIndex == 8
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                        trailing: Icon(
                          _userSectionExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: white.withOpacity(0.7),
                          size: 16,
                        ),
                        backgroundColor:
                            _userSectionExpanded
                                ? white.withOpacity(0.15)
                                : Colors.transparent,
                        onExpansionChanged: (expanded) {
                          setState(() {
                            _userSectionExpanded = expanded;
                          });
                        },
                        children: [
                          if (authProvider.isAuthenticated) ...[
                            _DrawerSubItem(
                              icon: Icons.person,
                              label:
                                  'ملفي الشخصي ${authProvider.userProfile?.user.username ?? ""}',
                              isSelected: widget.selectedIndex == 8,
                              onTap: () {
                                Navigator.pop(context);
                                if (widget.onItemSelected != null) {
                                  widget.onItemSelected!(8);
                                } else {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const ProfileScreen(),
                                    ),
                                  );
                                }
                              },
                              accentCyan: white,
                              textPrimary: white,
                            ),
                            _DrawerSubItem(
                              icon: Icons.receipt_long_rounded,
                              label: 'طلباتي',
                              isSelected: widget.selectedIndex == 2,
                              onTap: () {
                                Navigator.pop(context);
                                if (widget.onItemSelected != null) {
                                  widget.onItemSelected!(2);
                                } else {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const OrdersScreen(),
                                    ),
                                  );
                                }
                              },
                              accentCyan: white,
                              textPrimary: white,
                            ),
                            _DrawerSubItem(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'رصيدي',
                              isSelected: widget.selectedIndex == 3,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const BalanceHistoryScreen(),
                                  ),
                                );
                              },
                              accentCyan: white,
                              textPrimary: white,
                            ),
                            _DrawerSubItem(
                              icon: Icons.send_rounded,
                              label: 'إرسال دفعة',
                              isSelected: widget.selectedIndex == 4,
                              onTap: () {
                                Navigator.pop(context);
                                if (widget.onItemSelected != null) {
                                  widget.onItemSelected!(4);
                                } else {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SendMoneyScreen(),
                                    ),
                                  );
                                }
                              },
                              accentCyan: white,
                              textPrimary: white,
                            ),
                            const Divider(
                              color: Colors.white24,
                              height: 1,
                              indent: 48,
                              endIndent: 16,
                            ),
                            _DrawerSubItem(
                              icon: Icons.logout,
                              label: 'تسجيل الخروج',
                              isSelected: false,
                              onTap: () async {
                                Navigator.pop(context);
                                await authProvider.logout();
                                if (context.mounted) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  );
                                }
                              },
                              accentCyan: Colors.red.shade300,
                              textPrimary: Colors.red.shade300,
                            ),
                          ] else ...[
                            _DrawerSubItem(
                              icon: Icons.login_rounded,
                              label: 'تسجيل الدخول',
                              isSelected: false,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              accentCyan: white,
                              textPrimary: white,
                            ),
                            _DrawerSubItem(
                              icon: Icons.person_add_rounded,
                              label: 'إنشاء حساب',
                              isSelected: false,
                              onTap: () {
                                Navigator.pop(context);
                                // Navigate to register screen
                              },
                              accentCyan: white,
                              textPrimary: white,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  // Terms
                  _DrawerItem(
                    icon: Icons.description_rounded,
                    label: 'الشروط',
                    isSelected: widget.selectedIndex == 7,
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.onItemSelected != null) {
                        widget.onItemSelected!(7);
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TermsScreen(),
                          ),
                        );
                      }
                    },
                    accentCyan: white,
                    textPrimary: white,
                  ),
                  // About
                  _DrawerItem(
                    icon: Icons.info_rounded,
                    label: 'عن الموقع',
                    isSelected: widget.selectedIndex == 6,
                    onTap: () {
                      Navigator.pop(context);
                      if (widget.onItemSelected != null) {
                        widget.onItemSelected!(6);
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        );
                      }
                    },
                    accentCyan: white,
                    textPrimary: white,
                  ),
                  // Notifications
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      if (authProvider.isAuthenticated) {
                        return _DrawerItem(
                          icon: Icons.notifications_rounded,
                          label: 'الإشعارات',
                          isSelected: widget.selectedIndex == 9,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                          },
                          accentCyan: white,
                          textPrimary: white,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  // WhatsApp Support
                  const Divider(
                    color: Colors.white24,
                    height: 16,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _DrawerItem(
                    icon: Icons.support_agent_rounded,
                    label: 'الدعم الفني - واتساب',
                    isSelected: false,
                    onTap: () async {
                      Navigator.pop(context);
                      // رقم واتساب الدعم الفني - قم بتغييره إلى رقمك
                      const whatsappNumber = '963982828275'; // بدون علامة +
                      // إزالة أي رموز غير رقمية
                      final cleanNumber = whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');
                      final whatsappUrl = 'https://wa.me/$cleanNumber';

                      try {
                        final uri = Uri.parse(whatsappUrl);
                        // محاولة فتح الرابط مباشرة
                        if (await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        )) {
                          // تم فتح الرابط بنجاح
                        } else {
                          // إذا فشل، جرب فتح الرابط في المتصفح
                          await launchUrl(
                            uri,
                            mode: LaunchMode.platformDefault,
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('خطأ في فتح واتساب: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              action: SnackBarAction(
                                label: 'فتح في المتصفح',
                                onPressed: () async {
                                  final uri = Uri.parse(whatsappUrl);
                                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                                },
                              ),
                            ),
                          );
                        }
                      }
                    },
                    accentCyan: const Color(0xFF25D366), // لون واتساب
                    textPrimary: const Color(0xFF25D366),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accentCyan;
  final Color textPrimary;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.accentCyan,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? accentCyan.withOpacity(0.15) : Colors.transparent,
        border: Border(
          right: BorderSide(
            color: isSelected ? accentCyan : Colors.transparent,
            width: 3,
          ),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? accentCyan : textPrimary.withOpacity(0.7),
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentCyan : textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

class _DrawerSubItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accentCyan;
  final Color textPrimary;

  const _DrawerSubItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.accentCyan,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? accentCyan.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? accentCyan : textPrimary.withOpacity(0.6),
          size: 18,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentCyan : textPrimary.withOpacity(0.8),
            fontSize: 13,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.only(
          left: 48,
          right: 16,
          top: 4,
          bottom: 4,
        ),
      ),
    );
  }
}
