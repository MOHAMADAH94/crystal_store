import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const AppDrawer(),
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
        title: const Text('من نحن'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // لا يوجد بيانات للتحديث في هذه الصفحة
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              'مرحباً بك في Crystal',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            const Text(
              '''تعريف التطبيق وطبيعة عمله:

نحن منصة رقمية متخصصة في خدمة أهلا شات (Ahlan Chat) فقط. نوفّر تحويل وشحن وحدات أهلا شات بسرعة وأمان عبر التطبيق، مع متابعة حالة الطلب لحظة بلحظة.

نلتزم بالشفافية في الأسعار والعمليات، وحماية بيانات العملاء، وتقديم دعم فني متواصل للإجابة عن استفساراتكم ومتابعة طلباتكم.

ادفع من رصيدك داخل الحساب، واختر الباقة المناسبة، وأدخل معرّف اللاعب — وسنتكفّل بتنفيذ العملية عبر خدمة أهلا شات المعتمدة.''',
              style: TextStyle(fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 24),
            _InfoCard(
              icon: Icons.chat_rounded,
              title: 'أهلا شات فقط',
              description: 'خدمة متخصصة في تحويل وشحن أهلا شات',
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.bolt_rounded,
              title: 'تنفيذ سريع',
              description: 'طلباتك تُعالج بسرعة مع متابعة حالة الطلب',
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.verified_user_rounded,
              title: 'آمن وواضح',
              description: 'أسعار واضحة وخصم مباشر من رصيد حسابك',
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.support_agent,
              title: 'دعم فني',
              description: 'فريقنا جاهز لمساعدتك عند الحاجة',
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
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

