import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../home/home_screen.dart';

class PinScreen extends StatefulWidget {
  final bool isFirstTime;
  final bool isUpdate;

  const PinScreen({
    super.key,
    this.isFirstTime = false,
    this.isUpdate = false,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    4,
    (_) => FocusNode(),
  );
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _error;
  bool _isConfirming = false;
  String? _firstPin;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onPinChanged(int index, String value) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String _getPin() {
    return _controllers.map((c) => c.text).join();
  }

  void _clearPin() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _submitPin() async {
    final pin = _getPin();
    
    if (pin.length != 4) {
      setState(() {
        _error = 'PIN يجب أن يكون 4 أرقام';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.isFirstTime) {
        // أول مرة: طلب تأكيد PIN
        if (!_isConfirming) {
          setState(() {
            _firstPin = pin;
            _isConfirming = true;
            _clearPin();
          });
          return;
        } else {
          // التحقق من تطابق PIN
          if (pin != _firstPin) {
            setState(() {
              _error = 'PIN غير متطابق. يرجى المحاولة مرة أخرى';
              _isConfirming = false;
              _firstPin = null;
              _clearPin();
            });
            return;
          }
          // حفظ PIN
          await _apiService.setPin(pin);
          if (!mounted) return;
          
          // تحديث الملف الشخصي
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.loadProfile();
          
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else if (widget.isUpdate) {
        // تحديث PIN: يحتاج PIN القديم
        // هذا سيتم التعامل معه في شاشة أخرى
        Navigator.of(context).pop(pin);
      } else {
        // التحقق من PIN - مرة واحدة فقط عند الدخول
        final verified = await _apiService.verifyPin(pin);
        if (!mounted) return;
        
        if (verified) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          setState(() {
            _error = 'PIN غير صحيح';
            _clearPin();
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _clearPin();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                _isConfirming
                    ? 'تأكيد PIN'
                    : widget.isFirstTime
                        ? 'تعيين PIN جديد'
                        : widget.isUpdate
                            ? 'تحديث PIN'
                            : 'أدخل PIN',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'أعد إدخال PIN للتأكيد'
                    : widget.isFirstTime
                        ? 'أدخل PIN جديد (4 أرقام)'
                        : widget.isUpdate
                            ? 'أدخل PIN الجديد'
                            : 'للمتابعة، يرجى إدخال PIN',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      obscureText: true,
                      enabled: !_isLoading,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      onChanged: (value) {
                        _onPinChanged(index, value);
                        // إرسال تلقائي عند إدخال الرقم الرابع
                        if (value.length == 1 && index == 3) {
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (_getPin().length == 4) {
                              _submitPin();
                            }
                          });
                        }
                      },
                      onSubmitted: (value) {
                        if (index == 3 && _getPin().length == 4) {
                          _submitPin();
                        }
                      },
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'تأكيد',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
