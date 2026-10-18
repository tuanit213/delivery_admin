import 'package:admin/models/cau_hinh_model.dart';
import 'package:admin/services/api_service.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../widgets/day_selector_widget.dart';
import '../widgets/warning_note_card.dart';

class SystemConfigScreen extends StatefulWidget {
  const SystemConfigScreen({super.key});

  @override
  State<SystemConfigScreen> createState() => _SystemConfigScreenState();
}

class _SystemConfigScreenState extends State<SystemConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _surchargeController;
  late TextEditingController _baseShippingFeeController;
  late TextEditingController _feePerKmController;
  late TextEditingController _maxWaitingMinutesController;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  bool _newPeak = false;
  bool _missingParameters = false;

  bool _isActive = true;
  String _maCd = 'CD01';

  List<bool> _selectedDays = [true, true, true, true, true, false, false];
  Map<String, dynamic>? _initialData;
  Map<String, String>? _initialParameters;

  @override
  void initState() {
    super.initState();
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();
    _surchargeController = TextEditingController();
    _baseShippingFeeController = TextEditingController(text: '15000');
    _feePerKmController = TextEditingController(text: '5000');
    _maxWaitingMinutesController = TextEditingController(text: '5');

    _fetchGioCaoDiemData();
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _surchargeController.dispose();
    _baseShippingFeeController.dispose();
    _feePerKmController.dispose();
    _maxWaitingMinutesController.dispose();
    super.dispose();
  }

  String _formatTimeTo24Hour(String timeStr) {
    try {
      final cleanStr = timeStr.trim();
      bool isPM = cleanStr.toUpperCase().contains('PM');
      bool isAM = cleanStr.toUpperCase().contains('AM');

      String timeOnly = cleanStr.replaceAll(
        RegExp(r'\s*(AM|PM)', caseSensitive: false),
        '',
      );
      List<String> parts = timeOnly.split(':');

      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      String hStr = hour.toString().padLeft(2, '0');
      String mStr = minute.toString().padLeft(2, '0');

      return "$hStr:$mStr:00";
    } catch (e) {
      return timeStr;
    }
  }

  Future<void> _fetchGioCaoDiemData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getGioCaoDiem(),
        ApiService.getThamSoHeThong(),
      ]);
      final responseData = results[0];

      if (!mounted) return;

      _newPeak = responseData is List && responseData.isEmpty;
      _initialData = null;
      if (_newPeak) {
        _initialData = {
          'maCd': '',
          'gioBatDau': '07:00:00',
          'gioKetThuc': '09:00:00',
          'heSoPhi': 1.0,
          'isActive': false,
          'cacNgayApDung': '1111100',
        };
        _populateFields(_initialData!);
      } else if (responseData is Map<String, dynamic> &&
          responseData.isNotEmpty) {
        _initialData = responseData;
        _populateFields(responseData);
      } else if (responseData is List && responseData.isNotEmpty) {
        _initialData = responseData.first as Map<String, dynamic>;
        _populateFields(_initialData!);
      }

      if (_initialData == null || results[1] is! List) {
        throw const FormatException('Cấu hình không đầy đủ.');
      }
      _populateSystemParameters(results[1] as List);
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _populateFields(Map<String, dynamic> data) {
    final model = CauHinhGioCaoDiemModel.fromJson(data);
    _maCd = model.maCd;
    _startTimeController.text = model.gioBatDau;
    _endTimeController.text = model.gioKetThuc;
    _surchargeController.text = model.heSoPhi.toString();

    _isActive = data['isActive'] == true;

    final rawDays = data['cacNgayApDung'] ?? data['days'];

    if (rawDays is String) {
      final daysString = rawDays.trim();

      if (daysString.length == 7) {
        _selectedDays = daysString
            .split('')
            .map((char) => char == '1')
            .toList();
      } else {
        _selectedDays = List<bool>.filled(7, false);
      }
    } else if (rawDays is List && rawDays.length == 7) {
      _selectedDays = List<bool>.from(rawDays.map((e) => e == true));
    }
  }

  void _populateSystemParameters(List data) {
    final values = <String, String>{};
    for (final item in data.whereType<Map>()) {
      values[(item['maThamSo'] ?? item['MaThamSo'] ?? '').toString()] =
          (item['giaTri'] ?? item['GiaTri'] ?? '').toString();
    }
    const requiredKeys = [
      'PHI_VAN_CHUYEN_CO_BAN',
      'PHI_MOI_KM',
      'THOI_GIAN_CHO_TOI_DA_PHUT',
    ];
    _missingParameters = requiredKeys.any(
      (key) => !values.containsKey(key) || values[key]!.isEmpty,
    );
    _baseShippingFeeController.text = values[requiredKeys[0]] ?? '';
    _feePerKmController.text = values[requiredKeys[1]] ?? '';
    _maxWaitingMinutesController.text = values[requiredKeys[2]] ?? '';
    _initialParameters = {
      'base': _baseShippingFeeController.text,
      'km': _feePerKmController.text,
      'wait': _maxWaitingMinutesController.text,
    };
  }

  Future<void> _saveGioCaoDiemData() async {
    if (_isLoading || _isSaving || _errorMessage != null) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> payload = {
        'maCd': _maCd,
        'gioBatDau': _formatTimeTo24Hour(_startTimeController.text),
        'gioKetThuc': _formatTimeTo24Hour(_endTimeController.text),
        'heSoPhi':
            double.tryParse(_surchargeController.text.replaceAll('x', '')) ??
            1.5,
        'moTa': 'Khung giờ cao điểm áp dụng phụ phí',
        'isActive': _isActive,
        'cacNgayApDung': _selectedDays
            .map((selected) => selected ? '1' : '0')
            .join(''),
      };

      final baseFee = double.tryParse(_baseShippingFeeController.text.trim());
      final feePerKm = double.tryParse(_feePerKmController.text.trim());
      final maxWaitingMinutes = int.tryParse(
        _maxWaitingMinutesController.text.trim(),
      );

      if (baseFee == null || !baseFee.isFinite || baseFee < 0) {
        throw Exception('Phí vận chuyển cơ bản không hợp lệ.');
      }

      if (feePerKm == null || !feePerKm.isFinite || feePerKm < 0) {
        throw Exception('Phí mỗi km không hợp lệ.');
      }

      if (maxWaitingMinutes == null || maxWaitingMinutes <= 0) {
        throw Exception('Thời gian chờ tối đa phải lớn hơn 0 phút.');
      }

      final parameters = {
        'base': baseFee.toStringAsFixed(0),
        'km': feePerKm.toStringAsFixed(0),
        'wait': maxWaitingMinutes.toString(),
      };
      final bool isSuccess = await ApiService.updateGioCaoDiem(payload);
      if (!isSuccess) throw Exception('Không thể lưu giờ cao điểm.');

      await Future.wait([
        ApiService.updateThamSoHeThong(
          maThamSo: 'PHI_VAN_CHUYEN_CO_BAN',
          giaTri: baseFee.toStringAsFixed(0),
          moTa: 'Phí mở cửa / phí vận chuyển cơ bản (VNĐ)',
        ),
        ApiService.updateThamSoHeThong(
          maThamSo: 'PHI_MOI_KM',
          giaTri: feePerKm.toStringAsFixed(0),
          moTa: 'Đơn giá cho mỗi km đường bộ (VNĐ/km)',
        ),
        ApiService.updateThamSoHeThong(
          maThamSo: 'THOI_GIAN_CHO_TOI_DA_PHUT',
          giaTri: maxWaitingMinutes.toString(),
          moTa:
              'Số phút tối đa đơn được phép chờ trước khi cần điều phối thủ công',
        ),
      ]);

      if (!mounted) return;

      if (isSuccess) {
        _newPeak = false;
        _missingParameters = false;
        _initialData = Map<String, dynamic>.from(payload);
        _initialParameters = parameters;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật cấu hình hệ thống thành công!'),
            backgroundColor: AppColors.statusGreen,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception('Cập nhật không thành công từ phía Server');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.statusRed,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetChanges() {
    if (_isLoading || _isSaving) return;
    _formKey.currentState?.reset();
    setState(() {
      if (_initialData != null) _populateFields(_initialData!);
      final values = _initialParameters;
      if (values != null) {
        _baseShippingFeeController.text = values['base']!;
        _feePerKmController.text = values['km']!;
        _maxWaitingMinutesController.text = values['wait']!;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã khôi phục cài đặt ban đầu.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 30),
    );
    if (picked != null && mounted) {
      controller.text = picked.format(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cấu hình tham số hệ thống',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Quản lý các quy định vận hành, giờ cao điểm và chính sách thù lao.',
                          style: TextStyle(color: AppColors.textSubtitle),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed:
                            (_isLoading || _isSaving || _errorMessage != null)
                            ? null
                            : _resetChanges,
                        child: const Text('Hủy thay đổi'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed:
                            (_isLoading || _isSaving || _errorMessage != null)
                            ? null
                            : _saveGioCaoDiemData,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save, size: 18),
                        label: Text(_isSaving ? 'Đang lưu...' : 'Lưu cấu hình'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),

              if (!_isLoading &&
                  _errorMessage == null &&
                  (_newPeak || _missingParameters))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${_missingParameters ? 'Chưa thiết lập đủ tham số phí và thời gian chờ. Nhập các ô còn trống trước khi lưu. ' : ''}'
                    '${_newPeak ? 'Chưa có khung giờ cao điểm; khung giờ mới đang tắt và chưa được lưu.' : ''}',
                    style: const TextStyle(color: Colors.deepOrange),
                  ),
                ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.statusRed,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Lỗi tải dữ liệu: $_errorMessage',
                              style: const TextStyle(
                                color: AppColors.statusRed,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _fetchGioCaoDiemData,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Quy định 10 (QD10) - Khung giờ cao điểm',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _isActive
                                                  ? AppColors.statusGreen
                                                        .withValues(alpha: 0.1)
                                                  : Colors.grey.withValues(
                                                      alpha: 0.2,
                                                    ),
                                              borderRadius: BorderRadius.zero,
                                            ),
                                            child: Text(
                                              _isActive
                                                  ? 'ĐANG KÍCH HOẠT'
                                                  : 'ĐÃ TẮT',
                                              style: TextStyle(
                                                color: _isActive
                                                    ? AppColors.statusGreen
                                                    : Colors.grey[700],
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Switch(
                                        value: _isActive,
                                        activeThumbColor: AppColors.primaryRed,
                                        onChanged: (val) {
                                          setState(() => _isActive = val);
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _startTimeController,
                                          readOnly: true,
                                          onTap: () =>
                                              _selectTime(_startTimeController),
                                          decoration: const InputDecoration(
                                            labelText: 'Giờ bắt đầu',
                                            suffixIcon: Icon(
                                              Icons.access_time,
                                              size: 20,
                                            ),
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (val) =>
                                              val == null || val.isEmpty
                                              ? 'Chưa chọn giờ'
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _endTimeController,
                                          readOnly: true,
                                          onTap: () =>
                                              _selectTime(_endTimeController),
                                          decoration: const InputDecoration(
                                            labelText: 'Giờ kết thúc',
                                            suffixIcon: Icon(
                                              Icons.access_time,
                                              size: 20,
                                            ),
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (val) =>
                                              val == null || val.isEmpty
                                              ? 'Chưa chọn giờ'
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _surchargeController,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Hệ số phụ phí (Surcharge)',
                                            hintText: 'VD: 1.5',
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (val) {
                                            final number = double.tryParse(
                                              (val ?? '')
                                                  .replaceAll('x', '')
                                                  .trim(),
                                            );
                                            if (number == null ||
                                                !number.isFinite ||
                                                number < 1 ||
                                                number > 10) {
                                              return 'Hệ số phải từ 1 đến 10';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  const Text(
                                    'Các ngày áp dụng trong tuần',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  DaySelectorWidget(
                                    selectedDays: _selectedDays,
                                    onChanged: (newDays) {
                                      setState(() {
                                        _selectedDays = newDays;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 30),
                                  const Divider(),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'Cấu hình phí vận chuyển',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Công thức: Phí cơ bản + (Số km đường bộ × Phí/km). '
                                    'Nếu đang trong giờ cao điểm, kết quả tiếp tục nhân hệ số phụ phí.',
                                    style: TextStyle(
                                      color: AppColors.textSubtitle,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller:
                                              _baseShippingFeeController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Phí vận chuyển cơ bản (VNĐ)',
                                            hintText: 'VD: 15000',
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (value) {
                                            final number = double.tryParse(
                                              value?.trim() ?? '',
                                            );
                                            if (number == null ||
                                                !number.isFinite ||
                                                number < 0) {
                                              return 'Phí không hợp lệ';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _feePerKmController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Phí mỗi km (VNĐ/km)',
                                            hintText: 'VD: 5000',
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (value) {
                                            final number = double.tryParse(
                                              value?.trim() ?? '',
                                            );
                                            if (number == null ||
                                                !number.isFinite ||
                                                number < 0) {
                                              return 'Phí/km không hợp lệ';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 30),
                                  const Divider(),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'Cấu hình thời gian chờ điều phối',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Đơn hàng vượt quá ngưỡng này sẽ được đánh dấu là cần điều phối thủ công.',
                                    style: TextStyle(
                                      color: AppColors.textSubtitle,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: 360,
                                    child: TextFormField(
                                      controller: _maxWaitingMinutesController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Thời gian chờ tối đa (phút)',
                                        hintText: 'VD: 5',
                                        suffixText: 'phút',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (value) {
                                        final number = int.tryParse(
                                          value?.trim() ?? '',
                                        );
                                        if (number == null || number <= 0) {
                                          return 'Thời gian phải lớn hơn 0 phút';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),

                          const Expanded(flex: 1, child: WarningNoteCard()),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
