# LogiRoute Admin

Ứng dụng điều phối viết bằng Flutter, với ảnh pixel quản trị viên gõ phím, chớp mắt và biểu đồ chuyển động.

## Chức năng

- Dashboard, bản đồ đơn hàng và tài xế.
- Quản lý đơn chờ, phân công tài xế với kiểm tra tải trọng và hạn mức COD.
- Duyệt hồ sơ và quản lý tài xế.
- Xem thu nhập, hợp đồng, cấu hình phí và đối soát COD.
- Tìm kiếm và hướng dẫn sử dụng.

Thu nhập hiển thị là khoản ghi nhận, chưa thực hiện giao dịch chi trả. Các quy tắc và quyền thao tác được backend kiểm tra.

## Chạy local

Cài Flutter tương thích Dart `^3.12.2`, sau đó chạy:

```sh
flutter pub get
flutter run -d chrome --web-port 8082 --dart-define=API_BASE_URL=http://127.0.0.1:5031
```

Backend LogiRoute phải chạy riêng tại cổng 5031. Cần tài khoản có vai trò `ADMIN` do backend cấp. Kho này không chứa backend, cơ sở dữ liệu hay mật khẩu trình diễn.

Trên Windows, nếu Flutter báo `Building with plugins requires symlink support`, bật Developer Mode trong Settings rồi chạy lại `flutter pub get`.

## Kiểm tra

```sh
flutter analyze
flutter test
```

## Build web

```sh
flutter build web --release --base-href=/admin/ --dart-define=API_BASE_URL=https://your-api.example.com
```

Thay địa chỉ API bằng gateway thực tế rồi đưa nội dung `build/web` lên đường dẫn `/admin/` của web server. Nếu chạy ở gốc domain, dùng `--base-href=/`. Khi phục vụ ứng dụng qua HTTPS, API cũng cần HTTPS và cấu hình CORS cho origin của ứng dụng.

## Cấu hình

- `API_BASE_URL`: gateway backend, mặc định `http://127.0.0.1:5031`.
- `MAP_TILE_URL`: URL tile XYZ.
- `GEOCODING_BASE_URL`: dịch vụ tìm địa chỉ tương thích Photon.

Bản đồ và tìm địa chỉ cần kết nối mạng. Phiên bản này tập trung vào Flutter Web. Các thư mục nền tảng được giữ trong mã nguồn; Android/iOS cần toolchain và kiểm thử thiết bị riêng. Windows desktop hiện tắt trong `pubspec.yaml`.

## Các ứng dụng liên quan

- [Khách hàng](https://github.com/tuanit213/delivery_user)
- [Tài xế](https://github.com/tuanit213/delivery_shipper)
