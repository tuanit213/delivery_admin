import 'dart:math' as math;
import '../../../shared/widgets/pixel_brand.dart';
import '../../../shared/widgets/pixel_grid.dart';
import '../../../shared/widgets/pixel_admin_scene.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import 'package:admin/services/api_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLoginInfo();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLoginInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isRemembered = prefs.getBool('remember_me') ?? false;
      if (!mounted) return;

      if (isRemembered) {
        final savedUsername = prefs.getString('saved_username') ?? '';
        setState(() {
          _rememberMe = true;
          _usernameController.text = savedUsername;
        });
      }
    } catch (e) {
      debugPrint('Lỗi không tìm thấy tài khoản đã lưu: $e');
    }
  }

  Future<void> _saveOrClearSession(String username) async {
    final prefs = await SharedPreferences.getInstance();

    if (_rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('saved_username', username);
    } else {
      await prefs.remove('remember_me');
      await prefs.remove('saved_username');
    }
  }

  void _handleLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      final isSuccess = await _checkLoginWithApi(username, password);
      final revision = ApiService.sessionRevision;

      if (mounted) {
        if (isSuccess) {
          await _saveOrClearSession(username);
          if (revision != ApiService.sessionRevision) {
            throw const AdminSessionChangedException();
          }
          ApiService.authenticated.value = true;

          if (mounted) {
            context.go('/dashboard');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _checkLoginWithApi(String username, String password) async {
    final previousRevision = ApiService.sessionRevision;
    int? signedInRevision;
    try {
      await ApiService.login(username, password);
      signedInRevision = ApiService.sessionRevision;

      final userData = await ApiService.getMe();
      if (signedInRevision != ApiService.sessionRevision) {
        throw const AdminSessionChangedException();
      }

      if (userData['role'] != 'ADMIN') {
        await ApiService.logout();

        throw Exception(
          'Truy cập bị từ chối. Chỉ tài khoản ADMIN mới được phép đăng nhập!',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      if (signedInRevision != ApiService.sessionRevision) {
        throw const AdminSessionChangedException();
      }
      await prefs.setString('admin_ma_tk', userData['userId'].toString());
      if (signedInRevision != ApiService.sessionRevision) {
        throw const AdminSessionChangedException();
      }
      await prefs.setString(
        'admin_ten_dang_nhap',
        userData['email'].toString(),
      );
      if (signedInRevision != ApiService.sessionRevision) {
        throw const AdminSessionChangedException();
      }
      await prefs.setString('admin_role', userData['role'].toString());
      if (signedInRevision != ApiService.sessionRevision) {
        throw const AdminSessionChangedException();
      }

      return true;
    } on AdminSessionChangedException {
      rethrow;
    } catch (e) {
      if ((signedInRevision ?? previousRevision) ==
          ApiService.sessionRevision) {
        await ApiService.logout();
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.backgroundGray,
    body: CustomPaint(
      painter: const PixelGrid(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          final pad = wide ? 40.0 : 20.0;
          return SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, constraints.maxHeight - pad * 2),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 6, child: _hero(false)),
                            const SizedBox(width: 56),
                            Expanded(flex: 5, child: _loginCard()),
                          ],
                        )
                      : Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: PixelBrand(),
                            ),
                            const SizedBox(height: 24),
                            _hero(true),
                            const SizedBox(height: 28),
                            _loginCard(),
                            const SizedBox(height: 24),
                            const Text(
                              'LOGIROUTE • MỖI ĐƠN HÀNG, MỘT HÀNH TRÌNH',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  Widget _hero(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!compact) ...[
        const PixelBrand(),
        const SizedBox(height: 32),
        _eyebrow('TRẠM ĐIỀU PHỐI LOGIROUTE'),
        const SizedBox(height: 18),
        const Text(
          'Điều phối rõ ràng.\nVận hành thông suốt.',
          style: TextStyle(
            fontSize: 42,
            height: 1.18,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Theo dõi đơn hàng, tài xế và COD\ntrong một không gian quản trị.',
          style: TextStyle(fontSize: 16, height: 1.65, color: AppColors.muted),
        ),
        const SizedBox(height: 28),
      ],
      Container(
        decoration: pixelPanel(shadow: 6),
        padding: const EdgeInsets.all(2),
        child: AspectRatio(aspectRatio: 3 / 2, child: const PixelAdminScene()),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _step('01', 'ĐIỀU PHỐI'),
          _step('02', 'GIÁM SÁT'),
          _step('03', 'ĐỐI SOÁT'),
        ],
      ),
      if (!compact) ...[
        const SizedBox(height: 24),
        const Text(
          'Thông tin rõ ràng cho từng quyết định vận hành.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ],
  );
  Widget _eyebrow(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: const BoxDecoration(
      color: AppColors.panel2,
      border: Border(left: BorderSide(color: AppColors.primaryRed, width: 4)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: AppColors.primaryRed,
      ),
    ),
  );
  Widget _step(String number, String title) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        color: AppColors.text,
        child: Text(
          number,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.panel,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        title,
        style: const TextStyle(
          fontSize: 9,
          letterSpacing: .8,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
      ),
    ],
  );
  Widget _loginCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: pixelPanel(shadow: 7),
    child: AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _eyebrow('ADMIN CONSOLE'),
                const Icon(Icons.login, color: AppColors.primaryRed, size: 20),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Chào mừng\ntrở lại!',
              style: TextStyle(
                fontSize: 32,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Đăng nhập để điều phối hành trình\nvà quản lý đơn hàng của bạn.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'TÀI KHOẢN',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameController,
              enabled: !_isLoading,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập tài khoản'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Email / tên đăng nhập',
                hintText: 'admin@logiroute.local',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'MẬT KHẨU',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
              validator: (value) => value == null || value.isEmpty
                  ? 'Vui lòng nhập mật khẩu'
                  : null,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: _isLoading
                      ? null
                      : () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 28,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: _isLoading
                        ? null
                        : (value) =>
                              setState(() => _rememberMe = value ?? false),
                  ),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'Ghi nhớ tài khoản',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'VÀO TRẠM ĐIỀU PHỐI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.line),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 16,
                  color: AppColors.muted,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Không gian dành cho quản trị viên LogiRoute',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
