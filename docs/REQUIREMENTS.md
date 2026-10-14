# Yêu cầu dự án SmartOmni (góc nhìn app mobile)

> Tổng hợp từ repo backend [SmartOmmi_BE](https://github.com/Hxvf123/SmartOmmi_BE): `README.md`, `docs/project-context.md`,
> `docs/architecture.md`, `docs/SmartOmni_Additional_Flows_Detailed.md`, `docs/erd.dbml` và mã nguồn controller/DTO/entity.
> Khi backend thay đổi, cập nhật file này và [API_CONTRACT.md](API_CONTRACT.md).

## 1. Sản phẩm là gì?

- **SmartOmni** là nền tảng **SaaS quản trị bán lẻ đa kênh** cho người bán trên **Shopee** và **TikTok Shop**.
- Mỗi **tenant** = một cửa hàng logic, kết nối **tối đa 1 shop Shopee + 1 shop TikTok Shop**, có Storefront riêng.
- **Khách KHÔNG mua hàng trên SmartOmni.** Storefront chỉ giới thiệu sản phẩm, chatbot tư vấn rồi **chuyển khách sang sàn** để đặt hàng. Không có giỏ hàng, checkout hay thanh toán đơn.
- Thanh toán trong hệ thống **chỉ dành cho gói SaaS** của tenant.
- Dữ liệu đơn/sản phẩm/tin nhắn lấy từ API sàn: **webhook** (gần thời gian thực) + **polling** (bù sự kiện bị bỏ lỡ).

## 2. Người dùng

| Vai trò | Giao diện (theo BE) | Trên app mobile |
|---|---|---|
| **Customer** | Storefront, Customer Portal | ✅ Khu vực Customer |
| **Staff** (code BE: `MANAGER`) | Merchant Portal | ✅ Khu vực Merchant |
| **Tenant Admin** (code BE: `ADMIN`) | Merchant Portal | ✅ Khu vực Merchant + mục quản trị |
| **Super Admin** (`SUPER_ADMIN`) | Super Admin Console | ❌ Không hỗ trợ - dùng web |

Quyết định cho mobile:
- **Một màn đăng nhập chung**, sau khi đăng nhập điều hướng theo role.
- Super Admin đăng nhập trên mobile sẽ bị từ chối với thông báo dùng web.

## 3. Yêu cầu chức năng theo role

### 3.1 Chung
| Mã | Yêu cầu | Nguồn BE |
|---|---|---|
| AUTH-1 | Đăng nhập bằng email + mật khẩu, nhận JWT (hạn 24h) | `POST /api/auth/login` |
| AUTH-2 | Khóa tạm tài khoản 15 phút sau 5 lần sai mật khẩu (BE xử lý, app hiển thị thông báo) | `AuthService` |
| AUTH-3 | Quên mật khẩu → nhận token (hạn 30 phút) → đặt mật khẩu mới ≥ 8 ký tự | `forgot-password`, `reset-password` |
| AUTH-4 | Đăng xuất (JWT stateless: xóa token ở máy) | `POST /api/auth/logout` |
| AUTH-5 | Tự đăng xuất khi token hết hạn / server trả 401 | - |
| AUTH-6 | Tenant bị khóa không được đăng nhập (BE: TODO FR-003) | - |

### 3.2 Customer
| Mã | Yêu cầu |
|---|---|
| CUS-1 | Xem danh sách / chi tiết sản phẩm của cửa hàng (Storefront) |
| CUS-2 | Nút "Mua trên Shopee / TikTok Shop" mở đúng trang sản phẩm trên sàn |
| CUS-3 | Chatbot AI tư vấn sản phẩm (sản phẩm riêng, chưa có API) |
| CUS-4 | Đăng ký tài khoản Customer Portal bằng email + số điện thoại (cơ chế xác minh chưa chốt) |
| CUS-5 | **Claim đơn**: chọn shop (sàn) + nhập mã đơn. Điều kiện: đơn **đã hoàn tất trên sàn** và **qua 15 ngày** kể từ `completed_at`; **mỗi đơn chỉ claim 1 lần** trong tenant; người claim hợp lệ đầu tiên được điểm (không xác minh là người mua) → cần giới hạn số lần thử |
| CUS-6 | **Điểm** = `floor(tiền hàng thực trả sau giảm giá / 1.000 ₫)`, **không** tính phí ship và thuế. Điểm **không hết hạn**, **không** dùng để đổi thưởng |
| CUS-7 | **Hạng** theo tổng điểm: Standard < 500 ≤ Silver < 1.000 ≤ Platinum < 1.500 ≤ Diamond. Thông thường không hạ hạng |
| CUS-8 | Xem voucher được Tenant Admin phát (mã dùng trên app sàn; BE gửi email khi tạo thành công) |
| CUS-9 | Điểm tích chung cho các shop trong **cùng tenant**; không gộp danh tính khách giữa Shopee và TikTok |

### 3.3 Staff
| Mã | Yêu cầu |
|---|---|
| STF-1 | Xem danh sách đơn đa kênh, lọc theo trạng thái, xem chi tiết |
| STF-2 | Xử lý luồng đơn nội bộ (vd: chuẩn bị hàng). **Không** tự đánh dấu hoàn tất / trả hàng (lấy từ sàn) |
| STF-3 | In vận đơn PDF |
| STF-4 | Ghi nhận hoàn/trả (`POST /api/returns`) |
| STF-5 | Tạo / sửa sản phẩm, SKU, ảnh, dán URL sản phẩm trên sàn |
| STF-6 | Xem và điều chỉnh tồn kho theo SKU; thay đổi được đồng bộ ngược lên sàn (outbox) |
| STF-7 | Nhận cảnh báo AI (sắp hết hàng, giá bất thường, nhu cầu tăng); xem dự báo nhu cầu theo SKU |
| STF-8 | Hộp thư CSKH chung: đọc/trả lời hội thoại Shopee/TikTok. AI **chỉ phân loại** tin "bình thường / khiếu nại", **không** tự trả lời. Phiên khiếu nại bị khóa đến khi Staff đánh dấu "Đã giải quyết" |
| STF-9 | Cảnh báo khi kết nối sàn lỗi / hết quyền (hiển thị lúc đăng nhập) |

### 3.4 Tenant Admin (gồm toàn bộ quyền Staff)
| Mã | Yêu cầu |
|---|---|
| ADM-1 | Tự đăng ký tạo tenant (onboarding: tên cửa hàng, subdomain, email, mật khẩu, gói) |
| ADM-2 | Kết nối shop Shopee / TikTok Shop (appKey, appSecret, tự nhập sản phẩm) - mỗi sàn 1 shop |
| ADM-3 | Dashboard BI: đơn, doanh thu, sản phẩm, tồn kho, theo kênh. **Ưu tiên tiếp theo của dự án**: phân tích chỉ số + AI tư vấn chiến lược |
| ADM-4 | Quản lý tài khoản Staff |
| ADM-5 | Chọn khách / nhóm hạng để **phát voucher** (nếu API sàn cho phép tạo voucher) |
| ADM-6 | Quản lý gói SaaS: xem gói, nâng/hạ cấp, thanh toán, hóa đơn |
| ADM-7 | Gửi yêu cầu hỗ trợ (support ticket) cho Super Admin |

## 4. Yêu cầu phi chức năng cho app

| Mã | Yêu cầu |
|---|---|
| NFR-1 | Android trước; iOS dùng chung code, kiểm tra build iOS trên CI |
| NFR-2 | Lưu JWT an toàn (Keychain / Android Keystore), không log token |
| NFR-3 | Gửi `Authorization: Bearer <JWT>`; **không** tự gửi `X-Tenant-Id` / `X-User-Role` (Nginx xóa các header này, tenant lấy từ JWT) |
| NFR-4 | Mọi lỗi API hiển thị thông điệp dễ hiểu; có trạng thái loading / rỗng / lỗi + thử lại |
| NFR-5 | Tiếng Việt mặc định, sẵn sàng tiếng Anh |
| NFR-6 | 3 môi trường dev / staging / prod; dev chạy được không cần backend (mock) |
| NFR-7 | CI bắt buộc pass (format, analyze, test) trước khi merge; chi phí 0đ |
| NFR-8 | Thao tác có thể gây trùng (gửi tin, tạo voucher) phải chống bấm lặp; timeout cần đối soát trước khi thử lại |

## 5. Phạm vi backend hiện tại (14/10/2026)

Backend mới có **khung** 7 service. API đủ cho: đăng nhập, đơn hàng (danh sách, đổi trạng thái), tạo/xem sản phẩm, điều chỉnh tồn, kết nối sàn, dự báo AI theo SKU, onboarding tenant.

**Chưa có API** (app dùng mock): danh sách sản phẩm, danh sách tồn kho, dashboard, cảnh báo AI tổng hợp, danh sách kết nối sàn, toàn bộ Customer Portal (đăng nhập khách, claim, điểm, voucher), hộp thư CSKH, quản lý Staff, gói SaaS/thanh toán, in vận đơn.

Chi tiết từng endpoint: [API_CONTRACT.md](API_CONTRACT.md).

## 6. Câu hỏi còn mở (cần chủ dự án / team BE trả lời)

1. Customer đăng nhập qua **cùng** `/api/auth/login` (trả `role: CUSTOMER`) hay endpoint riêng? App đang giả định **dùng chung**.
2. Một tài khoản Customer thuộc 1 tenant hay nhiều tenant? (Ảnh hưởng màn chọn cửa hàng.)
3. Có cần refresh token không? Hiện JWT sống 24h, hết hạn phải đăng nhập lại.
4. Staff có phân quyền con không (vd: chỉ xem đơn, không sửa tồn)?
5. Có cần push notification (đơn mới, cảnh báo AI, tin nhắn khách)? Nếu có cần Firebase Cloud Messaging (miễn phí).
6. Upload ảnh sản phẩm lưu ở đâu (S3/MinIO/...) và API nào?
7. Các câu hỏi gốc trong `docs/project-context.md` của backend (ID khách chat ↔ người mua, scope API sàn, endpoint tạo voucher...).
