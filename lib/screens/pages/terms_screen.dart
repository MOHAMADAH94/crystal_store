import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
        title: const Text('الشروط والأحكام'),
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
              Icons.description_outlined,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            _Section(
              title: '1. خصوصية المعلومات ',
              content:
                  '''

يلتزم التطبيق بالحفاظ على خصوصية المستخدمين وفق الضوابط التالية: - جمع الحد الأدنى من البيانات اللازمة لتقديم الخدمة فقط. - عدم مشاركة أي بيانات شخصية مع أطراف ثالثة إلا بموافقة المستخدم أو بناءً على طلب رسمي

من الجهات المختصة.

- عدم استخدام بيانات المستخدم لأغراض تسويقية أو إعلانية دون إذن مسبق. - الاحتفاظ بسجلات الطلبات لأغراض التوثيق والمحاسبة وضمان جودة الخدمة.
''',
            ),
            const SizedBox(height: 24),
            _Section(
              title: '2.  مسؤوليات المستخدم',
              content:
                  '''

عند استخدام التطبيق يلتزم المستخدم بما يلي: تقديم معلومات صحيحة ودقيقة عند طلب أي خدمة، مثل رقم الهاتف. - عدم استخدام التطبيق لأي نشاط غير قانوني أو مخالف للأنظمة المعمول بها. - الالتزام بدفع قيمة الخدمات عبر المكتب المعتمد.

- عدم محاولة اختراق التطبيق أو التلاعب بنظام الطلبات أو استغلال أي ثغرة محتملة. - التأكد من صحة البيانات قبل تأكيد الطلب، حيث لا يتحمل التطبيق مسؤولية الأخطاء الناتجة عن

إدخال معلومات غير صحيحة.


''',
            ),
            const SizedBox(height: 24),
            _Section(
              title: '3. الإجراءات المتخذة عند مخالفة المستخدم لسياسة الاستخدام',
              content:
                  '''

تحتفظ الجهة المسؤولة عن التطبيق بالحق في اتخاذ الإجراءات المناسبة عند ثبوت قيام المستخدم بأي مخالفة لشروط وسياسات الاستخدام، وتشمل هذه الإجراءات - دون حصر - ما يلي:

تنبيه المستخدم بشأن المخالفة وطلب تصحيح السلوك أو تعديل البيانات الخاطئة. - تعليق الحساب مؤقتا ومنع المستخدم من الوصول إلى بعض أو جميع خدمات التطبيق لحين معالحة المخالفة. إلغاء الطلبات التي تم تنفيذها بناءً على معلومات غير صحيحة أو نشاط مشبوه أو مخالف للقوانين. - حظر الحساب بشكل دائم في حال تكرار المخالفات أو ثبوت وجود نية احتيال أو إساءة استخدام للخدمات. اتخاذ الإجراءات القانونية اللازمة ضد أي محاولة اختراق، أو تلاعب بالأنظمة، أو استخدام غير مشروع للخدمات. - حجب الوصول إلى التطبيق من الأجهزة أو الشبكات التي يثبت استخدامها في أنشطة مخالفة أو ضارة.

مع الاحتفاظ بالحق الكامل في اتخاذ أي إجراء إضافي نراه مناسبا
''',
            ),
            const SizedBox(height: 24),
            
          ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;

  const _Section({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 16, height: 1.6),
        ),
      ],
    );
  }
}

