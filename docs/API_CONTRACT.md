# Hợp đồng API (màn hình ↔ backend)

- Mọi request đi qua **Nginx Gateway** `:8080`, header `Authorization: Bearer <JWT>` (trừ login/quên mật khẩu).
- Response chuẩn: `{ "success": bool, "message": string?, "data": T, "timestamp": ISO-8601 }`.
- Phân trang theo Spring: `?page=0&size=20&sort=createdAt,desc` → `data: { content: [...], totalElements, totalPages, number, size }`.
- Enum gửi/nhận viết HOA: `SHOPEE`, `TIKTOK_SHOP`, `PENDING`, `TO_SHIP`...

Chú thích cột **Trạng thái**:
- ✅ **Thật** - backend đã có, app gọi API khi `USE_MOCK=false`.
- 🟡 **Mock** - backend chưa có API, app luôn dùng dữ liệu mẫu (màn hình có dải "Dữ liệu mẫu").
- ⚪ **Chưa làm** - chưa có màn hình (mục "Sắp có").

## 1. Xác thực

| Màn hình | Method & Path | Body / Query | Trạng thái | Ghi chú |
|---|---|---|---|---|
| Đăng nhập | `POST /api/auth/login` | `{ email, password }` → `{ accessToken, role, tenantId, userId }` | ✅ | Role: `ADMIN`, `MANAGER`, `SUPER_ADMIN`. **Cần BE bổ sung `CUSTOMER`** |
| Đăng xuất | `POST /api/auth/logout` | - | ✅ | Lỗi vẫn xóa token ở máy |
| Quên mật khẩu | `POST /api/auth/forgot-password` | `{ email }` | ✅ | BE chưa gửi email thật (TODO) |
| Đặt lại mật khẩu | `POST /api/auth/reset-password` | `{ token, newPassword }` (≥ 8 ký tự) | ✅ | |
| Đăng ký khách | - | - | ⚪ | Đề xuất `POST /api/customers/register` |
| Đăng ký tenant | `POST /api/tenants/onboarding` | `{ businessName, subdomain, adminEmail, adminPassword, initialPlanName }` | ⚪ | Chưa có màn hình trên mobile |

JWT payload: `{ sub: "<userId>", role, tenantId?, iat, exp }` (HS256, hạn 24h).

## 2. Merchant (Staff + Tenant Admin)

| Màn hình | Method & Path | Body / Query | Trạng thái | Repository |
|---|---|---|---|---|
| Tổng quan | - | - | 🟡 | `dashboardSummaryProvider` |
| Danh sách đơn | `GET /api/orders` | `page, size, sort` → `Page<Order>` | ✅ | `OrdersRemoteRepository.fetchOrders` |
| Chi tiết đơn | - (lấy từ danh sách) | - | ✅ | Đề xuất BE thêm `GET /api/orders/{id}` kèm `items` |
| Chuyển trạng thái đơn | `PATCH /api/orders/{id}/status` | `?status=TO_SHIP` | ✅ | App chỉ cho `PENDING → TO_SHIP` |
| Ghi nhận hoàn/trả | `POST /api/returns` | `{ orderId, reason }` | ✅ | |
| In vận đơn | - | - | ⚪ | Đề xuất `GET /api/orders/{id}/shipping-label` (PDF) |
| Danh sách sản phẩm | - | - | 🟡 | Đề xuất `GET /api/products?page&size&keyword` |
| Chi tiết sản phẩm | `GET /api/products/{id}` + `GET /api/products/{id}/skus` | - | ✅ | |
| Tạo sản phẩm | `POST /api/products` | `{ name, description?, skus: [{ skuCode, variantName?, basePrice }] }` | ✅ | |
| Danh sách tồn kho | - | - | 🟡 | Đề xuất `GET /api/inventory?lowStock=true` → `[{ skuId, skuCode, productName, quantityOnHand, reservedQuantity }]` |
| Đặt lại tồn | `POST /api/inventory/{skuId}/adjust` | `?quantity=<số tồn MỚI>` | ✅ | BE **gán** số lượng, không cộng/trừ |
| Dự báo theo SKU | `GET /api/ai/forecast/{skuId}` | → `[DemandForecast]` | ✅ | |
| Gợi ý sản phẩm | `GET /api/ai/recommendations/{skuId}` | | ⚪ | Chưa có màn hình |
| Cảnh báo AI | - | - | 🟡 | Đề xuất `GET /api/ai/alerts` |
| Hộp thư CSKH | - | - | ⚪ | Chờ Message Service |

### Chỉ Tenant Admin

| Màn hình | Method & Path | Body / Query | Trạng thái | Ghi chú |
|---|---|---|---|---|
| Danh sách kết nối sàn | - | - | 🟡 | Đề xuất `GET /api/marketplace-connections` |
| Kết nối sàn | `POST /api/marketplace-connections` | `{ platform, appKey, appSecret, autoImportProducts }` | ✅ | |
| Quản lý Staff | - | - | ⚪ | |
| Phát voucher | - | - | ⚪ | Phụ thuộc API tạo voucher của sàn |
| Gói SaaS | - | - | ⚪ | `subscription_plans`, `tenant_invoices` đã có trong ERD |
| Hỗ trợ | - | - | ⚪ | Bảng `support_tickets` đã có, Nginx đã route `/api/support-tickets/` |

## 3. Customer

| Màn hình | API đề xuất cho backend | Trạng thái |
|---|---|---|
| Danh sách sản phẩm (Storefront) | `GET /api/storefront/products` (công khai theo tenant, chỉ sản phẩm ACTIVE + URL sàn) | 🟡 |
| Chi tiết sản phẩm | `GET /api/storefront/products/{id}` | 🟡 |
| Điểm & hạng | `GET /api/customer/loyalty` → `{ totalPoints, tier, history: [{ orderCode, platform, points, claimedAt }] }` | 🟡 |
| Voucher | `GET /api/customer/vouchers` → `[{ code, platform, description, expiresAt }]` | 🟡 |
| Claim đơn | `POST /api/customer/claims` `{ platform, orderCode }` → `{ points }`; lỗi trả `message` rõ lý do (chưa hoàn tất / chưa đủ 15 ngày / đã claim / không tìm thấy) | 🟡 |
| Chatbot | `POST /api/storefront/chat` | ⚪ |

## 4. Đề xuất gửi team backend

1. **Thêm role `CUSTOMER`** vào `/api/auth/login` (hoặc endpoint riêng `/api/customer/auth/login`) - app đang dùng chung màn đăng nhập.
2. Các API danh sách còn thiếu: `GET /api/products`, `GET /api/inventory`, `GET /api/marketplace-connections`, `GET /api/orders/{id}`.
3. **Trả DTO thay vì entity** (README backend đã nêu nguyên tắc này) để tránh lộ trường như `appSecretEncrypted`.
4. Giữ định dạng lỗi `{ success: false, message }` cho mọi lỗi (kể cả 401/403 từ Spring Security) để app hiển thị đúng.
5. Cấu hình CORS không cần cho mobile, nhưng cần cho web portal sau này.
6. **Trả kèm `errorCode`** trong body lỗi (`{ success: false, message, errorCode }`). `BusinessException` đã có mã (`INVALID_CREDENTIALS`, `ACCOUNT_TEMP_LOCKED`, `ACCOUNT_DISABLED`) nhưng `GlobalExceptionHandler` chưa gửi ra, nên màn A-02 đang phải đoán loại lỗi qua nội dung `message` (xem `lib/features/auth/domain/auth_failure.dart`).
7. **Khóa tenant khi đăng nhập (FR-003):** app chờ `403` với `errorCode: TENANT_LOCKED` (mock đang giả lập đúng như vậy).
