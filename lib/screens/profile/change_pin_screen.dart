import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final List<TextEditingController> _oldPinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> _newPinControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _oldPinFocusNodes = List.generate(
    4,
    (_) => FocusNode(),
  );
  final List<FocusNode> _newPinFocusNodes = List.generate(
    4,
    (_) => FocusNode(),
  );
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _error;
  bool _isConfirming = false;
  String? _oldPin;
  String? _newPin;

  @override
  void dispose() {
    for (var controller in _oldPinControllers) {
      controller.dispose();
    }
    for (var controller in _newPinControllers) {
      controller.dispose();
    }
    for (var node in _oldPinFocusNodes) {
      node.dispose();
    }
    for (var node in _newPinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getPin(List<TextEditingController> controllers) {
    return controllers.map((c) => c.text).join();
  }

  void _clearPin(List<TextEditingController> controllers, List<FocusNode> focusNodes) {
    for (var controller in controllers) {
      controller.clear();
    }
    focusNodes[0].requestFocus();
  }

  void _onPinChanged(int index, String value, List<FocusNode> focusNodes) {
    if (value.length == 1 && index < 5) {
      focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _submitOldPin() async {
    final pin = _getPin(_oldPinControllers);
    
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
      final verified = await _apiService.verifyPin(pin);
      if (!mounted) return;
      
      if (verified) {
        setState(() {
          _oldPin = pin;
          _clearPin(_oldPinControllers, _oldPinFocusNodes);
        });
      } else {
        setState(() {
          _error = 'PIN القديم غير صحيح';
          _clearPin(_oldPinControllers, _oldPinFocusNodes);
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _clearPin(_oldPinControllers, _oldPinFocusNodes);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitNewPin() async {
    final pin = _getPin(_newPinControllers);
    
    if (pin.length != 4) {
      setState(() {
        _error = 'PIN يجب أن يكون 4 أرقام';
      });
      return;
    }

    if (!_isConfirming) {
      setState(() {
        _newPin = pin;
        _isConfirming = true;
        _clearPin(_newPinControllers, _newPinFocusNodes);
      });
      return;
    }

    // التحقق من تطابق PIN
    if (pin != _newPin) {
      setState(() {
        _error = 'PIN غير متطابق. يرجى المحاولة مرة أخرى';
        _isConfirming = false;
        _newPin = null;
        _clearPin(_newPinControllers, _newPinFocusNodes);
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _apiService.updatePin(_oldPin!, pin);
      if (!mounted) return;
      
      // تحديث الملف الشخصي
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.loadProfile();
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث PIN بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isConfirming = false;
        _newPin = null;
        _clearPin(_newPinControllers, _newPinFocusNodes);
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
      appBar: AppBar(
        title: const Text('تغيير PIN'),
      ),
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
                _oldPin == null
                    ? 'أدخل PIN القديم'
                    : _isConfirming
                        ? 'تأكيد PIN الجديد'
                        : 'أدخل PIN الجديد',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _oldPin == null
                    ? 'للمتابعة، يرجى إدخال PIN الحالي'
                    : _isConfirming
                        ? 'أعد إدخال PIN الجديد للتأكيد'
                        : 'أدخل PIN جديد (4 أرقام)',
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
                      controller: _oldPin == null
                          ? _oldPinControllers[index]
                          : _newPinControllers[index],
                      focusNode: _oldPin == null
                          ? _oldPinFocusNodes[index]
                          : _newPinFocusNodes[index],
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
                        _onPinChanged(
                          index,
                          value,
                          _oldPin == null ? _oldPinFocusNodes : _newPinFocusNodes,
                        );
                        // إرسال تلقائي عند إدخال الرقم الرابع
                        if (value.length == 1 && index == 3) {
                          Future.delayed(const Duration(milliseconds: 100), () {
                            final pin = _oldPin == null
                                ? _getPin(_oldPinControllers)
                                : _getPin(_newPinControllers);
                            if (pin.length == 4) {
                              if (_oldPin == null) {
                                _submitOldPin();
                              } else {
                                _submitNewPin();
                              }
                            }
                          });
                        }
                      },
                      onSubmitted: (value) {
                        if (index == 3) {
                          if (_oldPin == null) {
                            _submitOldPin();
                          } else {
                            _submitNewPin();
                          }
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
                  onPressed: _isLoading
                      ? null
                      : _oldPin == null
                          ? _submitOldPin
                          : _submitNewPin,
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
