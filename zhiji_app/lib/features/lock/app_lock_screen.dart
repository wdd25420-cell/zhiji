import "package:flutter/material.dart";
import "../../core/database/app_database.dart";
import "../../core/database/daos/common_daos.dart";

/// 应用锁 PIN 码设置/验证界面
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.db});

  final AppDatabase db;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _pin = "";
  String? _confirmPin;
  bool _isSetup = false;
  bool _lockedOut = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final dao = SettingsDao(widget.db);
    final stored = await dao.getValue("lock_pin_hash");
    setState(() => _isSetup = stored != null && stored.isNotEmpty);
  }

  String _hash(String pin) {
    // 简单 hash（本地加密级别的安全性已足够，allowBackup=false）
    int hash = 5381;
    for (int i = 0; i < pin.length; i++) {
      hash = ((hash << 5) + hash) + pin.codeUnitAt(i);
    }
    return hash.toRadixString(16);
  }

  void _onDigit(String d) {
    if (_lockedOut) return;
    if (_pin.length >= 6) return;
    setState(() => _pin += d);

    if (_pin.length == 6) {
      if (_isSetup && _confirmPin == null) {
        _verifyPin();
      } else if (_confirmPin == null) {
        setState(() => _confirmPin = _pin);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _pin = "");
        });
      } else {
        if (_pin == _confirmPin) {
          _setPin();
        } else {
          setState(() {
            _pin = "";
            _confirmPin = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("两次 PIN 不一致，请重试")),
          );
        }
      }
    }
  }

  Future<void> _verifyPin() async {
    final dao = SettingsDao(widget.db);
    final stored = await dao.getValue("lock_pin_hash");
    if (stored == _hash(_pin)) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      _attempts++;
      setState(() => _pin = "");
      if (_attempts >= 3) {
        setState(() => _lockedOut = true);
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted) setState(() { _lockedOut = false; _attempts = 0; });
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_lockedOut ? "已锁定 30 秒" : "PIN 错误，剩余 ${3 - _attempts} 次")),
        );
      }
    }
  }

  Future<void> _setPin() async {
    final dao = SettingsDao(widget.db);
    await dao.setValue("lock_pin_hash", _hash(_pin));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ 应用锁已启用")),
      );
      Navigator.of(context).pop(true);
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty && !_lockedOut) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isSetup ? "验证 PIN" : "设置应用锁")),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: cs.primary),
            const SizedBox(height: 24),
            Text(
              _confirmPin != null ? "请再次输入 PIN" : _isSetup ? "输入 PIN 解锁" : "设置 6 位数字 PIN",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16, height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? cs.primary : cs.surfaceContainerHighest,
                ),
              )),
            ),
            if (_lockedOut)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text("已锁定，请等待 30 秒", style: TextStyle(color: cs.error)),
              ),
            const SizedBox(height: 48),
            _NumberPad(onDigit: _onDigit, onDelete: _onDelete),
          ],
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.onDigit, required this.onDelete});
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in [['1','2','3'], ['4','5','6'], ['7','8','9']])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((d) => SizedBox(
              width: 80, height: 60,
              child: TextButton(
                onPressed: () => onDigit(d),
                child: Text(d, style: const TextStyle(fontSize: 24)),
              ),
            )).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80, height: 60),
            SizedBox(
              width: 80, height: 60,
              child: TextButton(
                onPressed: () => onDigit('0'),
                child: const Text('0', style: TextStyle(fontSize: 24)),
              ),
            ),
            SizedBox(
              width: 80, height: 60,
              child: IconButton(
                icon: const Icon(Icons.backspace_outlined),
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
