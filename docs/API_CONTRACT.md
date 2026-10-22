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
| Đăng ký tenant | `POST /api/tenants/onboarding` | `{ businessName, subdomain, adminEmail, adminPassword, initialPlanName }` | - | Chỉ làm trên web portal, không làm trên mobile (chốt 22/10/2026) |

JWT payload: `{ sub: "<userId>", role, tenantId?, iat, exp }` (HS256, hạn 24h).

## 2. Merchant (Staff + Tenant Admin)

| Màn hình | Method & Path | Body / Query | Trạng thái | Repository |
|---|---|---|---|---|
| Tổng quan | - | - | 🟡 | `dashboardSummaryProvider` |
| Danh sách đơn | `GET /api/orders` | `page, size, sort` → `Page<Order>` | ✅ | `OrdersRemoteRepository.fetchOrders` |
| Chi tiết đơn | - (lấy từ danh sách) | - | ✅ | Đề xuất BE thêm `GET /api/orders/{id}` kèm `items` |
| Chuyển trạng thái đơn | `PATCH /api/orders/{id}/status` | `?status=TO_SHIP` | ✅ | App chỉ cho `PENDING → TO_SHIP` |
| Ghi nhận hoàn/trả | `POST /api/returns` | `{ orderId, reason }` | ✅ | |
| In vận đơn | - | - | 🟡 | Đề xuất `GET /api/orders/{id}/shipping-label` (PDF); app dùng tem mẫu |
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
| Quản lý Staff | - | - | 🟡 | App dùng mock (`StaffRepository`): danh sách, thêm (email + mật khẩu tạm), khóa / mở khóa |
| Phát voucher | - | - | 🟡 | Phụ thuộc API tạo voucher của sàn; app dùng mock (`VoucherRepository`) |
| Gói SaaS | - | - | 🟡 | `subscription_plans`, `tenant_invoices` đã có trong ERD; app dùng mock (`SubscriptionRepository`), chưa thanh toán trong app |
| Hỗ trợ | - | - | 🟡 | Bảng `support_tickets` đã có, Nginx đã route `/api/support-tickets/`; app dùng mock (`SupportRepository`): danh sách + tạo (tiêu đề, mô tả) |

## 3. Customer

| Màn hình | API đề xuất cho backend | Trạng thái |
|---|---|---|
| Danh sách sản phẩm (Storefront) | `GET /api/storefront/products` (công khai theo tenant, chỉ sản phẩm ACTIVE + URL sàn) | 🟡 |
| Chi tiết sản phẩm | `GET /api/storefront/products/{id}` | 🟡 |
| Điểm & hạng | `GET /api/customer/loyalty` → `{ totalPoints, tier, history: [{ orderCode, platform, points, claimedAt }] }` | 🟡 |
| Voucher | `GET /api/customer/vouchers` → `[{ code, platform, description, expiresAt }]` | 🟡 |
| Claim đơn | `POST /api/customer/claims` `{ platform, orderCode }` → `{ points }`; lỗi trả `message` rõ lý do (chưa hoàn tất / chưa đủ 15 ngày / đã claim / không tìm thấy) | 🟡 |
| Chatbot | `POST /api/storefront/chat` | ⚪ |
| Đăng ký khách (A-05) | `POST /api/customers/register` `{ shopCode, fullName, email, phone, password }` → gửi OTP; `POST /api/customers/verify-email` `{ email, otp }` → `{ accessToken }` | ⚪ (mock) |
| Cửa hàng của khách (C-00) | `GET /api/customer/shops` → `[{ tenantId, name, logoUrl, tier, points }]`; `GET /api/storefront/shops/{shopCode}` (xem trước); `POST /api/customer/shops` `{ shopCode }` (tham gia) | ⚪ (mock) |

**Nhiều cửa hàng:** mọi API `/api/customer/*` và `/api/storefront/*` nhận cửa hàng đang xem qua header `X-Tenant-Id` (đề xuất). JWT của khách không mang `tenantId` cố định.

## 4. API app đang chờ backend (gửi team backend)

Cập nhật 22/10/2026, bản app v0.1.0. Mỗi dòng: màn hình dùng API, endpoint **đề xuất** (backend có thể đổi tên, chỉ cần báo lại), và repository mock đang thay thế trong app. Khi backend có API, app chỉ thêm `…RemoteRepository` cùng interface, màn hình không đổi.

Quy ước chung: response `{ success, message, data, timestamp }`, enum viết HOA, phân trang kiểu Spring (đầu file), header `Authorization: Bearer <JWT>`.

### 4.1. Xác thực

| Màn hình | Endpoint đề xuất | Mock đang thay thế |
|---|---|---|
| A-02 Đăng nhập (khách) | `POST /api/auth/login` trả thêm role `CUSTOMER` (hoặc `POST /api/customer/auth/login`) | `AuthMockRepository` (tài khoản demo) |
| A-05 Đăng ký khách | `POST /api/customers/register` `{ shopCode, fullName, email, phone, password }` → gửi OTP | `RegistrationMockRepository.register` |
| A-05 OTP | `POST /api/customers/verify-email` `{ email, otp }` → `{ accessToken, role, userId }`; `POST /api/customers/resend-otp` `{ email }` | `RegistrationMockRepository.verifyEmail`, `.resendOtp` |

### 4.2. Merchant (Staff + Tenant Admin)

| Màn hình | Endpoint đề xuất | Mock đang thay thế |
|---|---|---|
| M-10 Tổng quan | `GET /api/dashboard/summary` → `{ ordersToday, pending, toShip, lowStockSkus, revenueToday?, revenueByChannel?, revenueLast7Days? }` (trường doanh thu chỉ trả cho Admin) | `dashboardSummaryProvider` (`dashboard_data.dart`) |
| M-10 Cảnh báo AI | `GET /api/ai/alerts` → `[{ skuId, skuCode, productName, type, message }]` | `dashboardSummaryProvider` (`dashboard_data.dart`) |
| M-21 Chi tiết đơn | `GET /api/orders/{id}` kèm `items: [{ skuCode, productName, variantName, quantity, unitPrice }]` | Đơn lấy từ danh sách; `items` chỉ có ở `OrdersMockRepository` |
| M-22 In vận đơn | `GET /api/orders/{id}/shipping-label` → `application/pdf`; `409` + `errorCode: LABEL_NOT_READY` khi sàn chưa tạo tem | `ShippingLabelMockRepository` (tem mẫu PDF) |
| M-30 Sản phẩm | `GET /api/products?page&size&keyword` | `ProductsMockRepository.listProducts` (cả khi `USE_MOCK=false`) |
| M-40 Tồn kho | `GET /api/inventory?lowStock=true` → `[{ skuId, skuCode, productName, variantName, quantityOnHand, reservedQuantity }]` | `InventoryMockRepository.listInventory` |
| M-60 Hộp thư CSKH | `GET /api/conversations?filter=ALL\|COMPLAINT\|UNREPLIED&platform=` | `InboxMockRepository.listConversations` |
| M-61 Hội thoại | `GET /api/conversations/{id}`, `GET /api/conversations/{id}/messages`, `POST /api/conversations/{id}/messages` `{ text }` → tin có `deliveryStatus` (`SENDING` / `SENT` / `UNKNOWN`), `POST /api/conversations/{id}/read`, `POST /api/conversations/{id}/resolve`, `PUT /api/conversations/{id}/order` `{ orderId }` | `InboxMockRepository` (chờ Message Service) |

### 4.3. Chỉ Tenant Admin

| Màn hình | Endpoint đề xuất | Mock đang thay thế |
|---|---|---|
| T-10 Kết nối sàn | `GET /api/marketplace-connections`, `DELETE /api/marketplace-connections/{platform}`, `PATCH /api/marketplace-connections/{platform}` `{ autoImportProducts }` | `MarketplaceMockRepository.listConnections`, `.disconnect`, `.setAutoImport` (kết nối App Key đã gọi API thật) |
| T-10 OAuth | Luồng OAuth của TikTok Shop / Shopee (chưa có đặc tả) | Chưa làm |
| T-20 Nhân viên | `GET /api/staff` → `[{ id, email, name, isOwner, active }]`; `POST /api/staff` `{ email, tempPassword }` (`409 EMAIL_EXISTS`); `PATCH /api/staff/{id}` `{ active }` (không cho khóa chủ cửa hàng) | `StaffMockRepository` |
| T-30 Phát voucher | `GET /api/customers?fields=id,name,email,tier` (khách của cửa hàng); `GET /api/vouchers/capabilities` → `{ SHOPEE: AVAILABLE\|UNSUPPORTED\|NOT_CONNECTED, … }`; `GET /api/voucher-batches`; `POST /api/voucher-batches` `{ platform, discount, minOrder, expiresAt, customerIds }` → đợt `CREATING`, sau đó `SUCCESS` / `FAILED` (+ `failureReason`) / `UNKNOWN`. Chỉ gửi email khi sàn xác nhận tạo thành công; đợt `UNKNOWN` cần đối soát, không tạo lại | `VoucherMockRepository` |
| T-40 Gói dịch vụ | `GET /api/subscription` → `{ planName, expiresAt, usage: { skus, connections, imageStorageGb } }` (mỗi mục `{ used, limit }`, `limit: null` = không giới hạn); `GET /api/tenant-invoices` → `[{ code, period, amount, paid, dueDate }]`. Đổi gói / thanh toán làm trên web | `SubscriptionMockRepository` |
| T-50 Hỗ trợ | `GET /api/support-tickets` → `[{ id, code, title, status: OPEN\|IN_PROGRESS\|RESOLVED, updatedAt, lastReply: { author: SUPPORT\|ME, text }? }]`; `POST /api/support-tickets` `{ title (≤ 120), description (≤ 2.000) }` | `SupportMockRepository` |

### 4.4. Customer

Mọi API `/api/customer/*` và `/api/storefront/*` nhận cửa hàng đang xem qua header `X-Tenant-Id` (đề xuất).

| Màn hình | Endpoint đề xuất | Mock đang thay thế |
|---|---|---|
| C-00 Cửa hàng của bạn | `GET /api/customer/shops` → `[{ tenantId, name, logoUrl, tier, points }]`; `GET /api/storefront/shops/{shopCode}` (xem trước); `POST /api/customer/shops` `{ shopCode }` (tham gia) | `CustomerShopMockRepository` |
| C-10 Sản phẩm | `GET /api/storefront/products` (chỉ sản phẩm ACTIVE + URL sàn) | `StorefrontMockRepository.listProducts` |
| C-11 Chi tiết sản phẩm | `GET /api/storefront/products/{id}` | `StorefrontMockRepository.getProduct` |
| C-12 Trợ lý | `POST /api/storefront/chat` `{ question }` → `{ text, productIds: [], fallback }` (không đặt hàng) | `ChatbotMockRepository` |
| C-20 Điểm & hạng | `GET /api/customer/loyalty` → `{ totalPoints, tier, history: [{ orderCode, platform, points, claimedAt }] }`; `GET /api/customer/vouchers` → `[{ code, platform, description, expiresAt }]` | `LoyaltyMockRepository.getSummary`, `.getVouchers` |
| C-30 Claim đơn | `POST /api/customer/claims` `{ platform, orderCode }` → `{ points, newTier? }`; lỗi có `errorCode` (`NOT_COMPLETED`, `WAITING_PERIOD` + ngày được claim, `ALREADY_CLAIMED`, `NOT_FOUND`, `TOO_MANY_ATTEMPTS` + thời gian chờ) | `LoyaltyMockRepository.claimOrder` |

### 4.5. Yêu cầu chung

1. **Thêm role `CUSTOMER`** vào `/api/auth/login` (hoặc endpoint riêng `/api/customer/auth/login`) - app đang dùng chung màn đăng nhập.
2. **Trả DTO thay vì entity** (README backend đã nêu nguyên tắc này) để tránh lộ trường như `appSecretEncrypted`.
3. Giữ định dạng lỗi `{ success: false, message }` cho mọi lỗi (kể cả 401/403 từ Spring Security) để app hiển thị đúng.
4. Cấu hình CORS không cần cho mobile, nhưng cần cho web portal sau này.
5. **Trả kèm `errorCode`** trong body lỗi (`{ success: false, message, errorCode }`). `BusinessException` đã có mã (`INVALID_CREDENTIALS`, `ACCOUNT_TEMP_LOCKED`, `ACCOUNT_DISABLED`) nhưng `GlobalExceptionHandler` chưa gửi ra, nên màn A-02 đang phải đoán loại lỗi qua nội dung `message` (xem `lib/features/auth/domain/auth_failure.dart`).
6. **Khóa tenant khi đăng nhập (FR-003):** app chờ `403` với `errorCode: TENANT_LOCKED` (mock đang giả lập đúng như vậy).
7. **Khách dùng nhiều cửa hàng:** tách tài khoản khách khỏi tenant (bảng nối khách–cửa hàng), thêm các API ở mục 3 (đăng ký + OTP, danh sách/tham gia cửa hàng) và header `X-Tenant-Id` cho API khách.
8. **Dự báo M-51, "Nên nhập thêm":** API dự báo trả `recommendedReorderQty` theo từng ngày. App đang hiển thị **giá trị lớn nhất trong 7 ngày** (`summarizeForecast` ở `lib/features/ai_insights/domain/demand_forecast.dart`). Cần backend xác nhận: đó là số nên nhập cho cả 7 ngày, hay phải cộng dồn, hay nên trả sẵn một con số tổng.
