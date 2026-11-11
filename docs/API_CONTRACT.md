# Hợp đồng API (màn hình ↔ backend)

Backend: [Smart-Omni/SmartOmni_BE](https://github.com/Smart-Omni/SmartOmni_BE), nhánh `develop`, đối chiếu ở commit `d4ea062`.

- Mọi request đi qua **Nginx Gateway** `:8080`, header `Authorization: Bearer <JWT>` (trừ login/quên mật khẩu).
- Response chuẩn: `{ "success": bool, "message": string?, "data": T, "timestamp": ISO-8601 }`.
- Phân trang theo Spring: `?page=0&size=20&sort=createdAt,desc` → `data: { content: [...], totalElements, totalPages, number, size }`.
- Enum gửi/nhận viết HOA: `SHOPEE`, `TIKTOK_SHOP`, `PENDING`, `TO_SHIP`...

Chú thích cột **Trạng thái**:
- ✅ **Thật** - backend đã có, app gọi API khi `USE_MOCK=false`.
- 🟡 **Mock** - backend chưa có API, app luôn dùng dữ liệu mẫu (màn hình có dải "Dữ liệu mẫu").
- ⚪ **Chưa làm** - chưa có màn hình (mục "Sắp có").

## 0. Tình trạng nối API (BE `develop` @ `d4ea062`)

Khi `USE_MOCK=false`, chức năng nào gọi API thật được chọn ở `lib/app/config/api_availability.dart` (`connectedFeatures`); chức năng chưa nối được dùng Mock và hiện `SoMockBanner`. Mọi đường dẫn API nằm ở `lib/core/network/api_paths.dart`. BE sửa xong: sửa đường dẫn (nếu đổi) rồi thêm chức năng vào `connectedFeatures`.

### ✅ Nối được ngay

| Màn | API BE | Ghi chú |
|---|---|---|
| A-02 Đăng nhập | `POST /api/v1/auth/login` | Đọc dạng mới: vai trò nằm trong `userInfo` |
| Đăng xuất | `POST /api/v1/auth/logout` | |
| A-03 Quên mật khẩu | `POST /api/v1/auth/forgot-password` | |
| A-04 Đặt lại mật khẩu | `POST /api/v1/auth/reset-password` | Gửi thêm ô nhập lại mật khẩu |
| Tự gia hạn phiên | `POST /api/v1/auth/refresh` | Không bị đá ra khi token hết hạn |
| A-05 Đăng ký khách | `POST /api/v1/auth/register` | Bỏ OTP khi dùng BE thật; mã cửa hàng gửi làm `subdomain` |
| M-50 Thông tin tài khoản | `GET /api/v1/users/me`, `GET /api/v1/tenants/me` | Tên, email, tên cửa hàng thật |
| Đổi mật khẩu (C-40, M-50 đang ghi "Sắp có") | `POST /api/v1/auth/change-password` | Bật lên được vì API đã có |

### ❌ Chưa nối được: lỗi và nguyên nhân (gửi BE)

| Màn trong app | API | Lỗi | Nguyên nhân |
|---|---|---|---|
| M-20, M-21 Đơn hàng, đổi trạng thái | `/api/orders` | 404 | Nginx chỉ cho qua `/api/v1/...`, còn `OrderController` vẫn nhận `/api/orders`. Gọi kiểu nào cũng không tới |
| Hoàn/trả (sheet ở M-21) | `/api/returns` | 404 | Như trên (`ReturnRefundController`) |
| M-30, M-31, M-32 Sản phẩm | `/api/products` | 404 | Như trên (`ProductController`). Ngoài ra chưa có API danh sách sản phẩm |
| M-40 Tồn kho | `/api/inventory` | 404 | Như trên (`InventoryController`). Chưa có API danh sách tồn |
| M-51 Dự báo AI | `/api/ai/forecast` | 404 | Như trên (`DemandForecastController`) |
| T-10 Kết nối sàn | `/api/marketplace-connections` | 404 | Như trên (`MarketplaceConnection`, `Shopee*`, `TiktokConnectionController`) |
| M-22 In vận đơn Shopee | `/api/marketplace-connections/shopee/...` | 404 | Như trên |
| T-20 Nhân viên | `/api/v1/users` | 403 | `UserController` chỉ cho role `ADMIN` hoặc `TENANT_OWNER`. Không có role `TENANT_OWNER`, chủ cửa hàng là `TENANT_ADMIN` nên bị chặn |
| M-10, M-60/61, T-30, T-40, T-50, C-00, C-10, C-11, C-12, C-20, C-30 | - | Chưa có API | BE chưa làm các chức năng này |
| A-05 Đăng ký khách | `/api/v1/auth/register` | Khách không gắn cửa hàng | `AuthServiceImpl.register` bỏ qua `subdomain`/`tenant_id`, khách tạo ra không gắn cửa hàng nào |
| A-05 Ô mã cửa hàng | `GET /api/v1/tenants/public/by-subdomain/{subdomain}` | 404 | Trả 404 cho khách chưa đăng nhập kể cả cửa hàng có thật (RLS chưa thiết lập ngữ cảnh đọc công khai). App chỉ kiểm định dạng mã |
| Mọi màn cần đăng nhập | - | Token hết hạn trả 403 (body rỗng) thay vì 401 | `SecurityConfig` chưa có `authenticationEntryPoint`. App đang tự refresh trước khi token hết hạn (đọc `exp`) để né lỗi này |
| Mọi màn khi có lỗi | - | Thông báo lỗi chung chung | Body lỗi chưa có `errorCode` (`GlobalExceptionHandler` chỉ gửi `message`) |
| Chạy thử | - | Không có sẵn tài khoản | BE chưa có dữ liệu demo. Phải tự tạo: mở cửa hàng qua web FE (`/api/v1/tenants/onboarding`) và đăng ký khách qua app |

## 1. Xác thực

| Màn hình | Method & Path | Body / Query | Trạng thái | Ghi chú |
|---|---|---|---|---|
| Đăng nhập | `POST /api/v1/auth/login` | `{ email, password }` → `AuthResponse` (dưới bảng) | ✅ | Role: `SUPER_ADMIN` (app từ chối), `ADMIN`, `TENANT_ADMIN`, `MANAGER`, `CUSTOMER` |
| Gia hạn phiên | `POST /api/v1/auth/refresh` | `{ refresh_token }` → `AuthResponse` | ✅ | BE xoay vòng refresh token: luôn lưu token mới. App refresh trước khi gửi nếu `exp` còn < 30 giây, và khi gặp 401 (gọi lại request một lần) |
| Đăng xuất | `POST /api/v1/auth/logout` | header `Authorization` | ✅ | BE blacklist access token, xóa refresh token. Lỗi vẫn xóa token ở máy |
| Quên mật khẩu | `POST /api/v1/auth/forgot-password` | `{ email }` | ✅ | |
| Đặt lại mật khẩu | `POST /api/v1/auth/reset-password` | `{ token, new_password, confirm_password }` (6–100 ký tự) | ✅ | |
| Đăng ký khách (A-05) | `POST /api/v1/auth/register` | `{ email, password (6–100), full_name, phone, subdomain }` → `AuthResponse` (201) | ✅ | Không có OTP: vào thẳng app. Ô "Mã cửa hàng" chỉ kiểm `^[a-z0-9-]{3,30}$` (chữ thường) rồi gửi làm `subdomain`; BE hiện bỏ qua trường này. Email trùng: 409. Mock vẫn có OTP |
| Hồ sơ (M-50, C-40) | `GET /api/v1/users/me` | → `UserProfileResponse` (snake_case): `{ id, email, full_name, phone, avatar, role, status, tenant_id, subdomain, created_at, updated_at }` | ✅ | Thẻ hồ sơ hiện họ tên, email |
| Tên cửa hàng (M-50) | `GET /api/v1/tenants/me` | → `TenantProfileResponse` (camelCase): `{ id, companyName, subdomain, status, …, storefront: { storeName, logoUrl, … } }` | ✅ | Chỉ gọi khi có `tenant_id`. Tên = `storefront.storeName`, trống thì `companyName`. Lỗi thì thẻ vẫn hiện tên, email |
| Đổi mật khẩu (C-40) | `POST /api/v1/auth/change-password` | `{ current_password, new_password (6–100), confirm_password }` | ✅ | Cần token. Lỗi 400 kèm `message` (sai mật khẩu hiện tại / trùng / không khớp). BE thu hồi refresh token nên app đăng xuất ngay, báo "Đã đổi mật khẩu, vui lòng đăng nhập lại." |
| Đăng ký tenant | `POST /api/tenants/onboarding` | `{ businessName, subdomain, adminEmail, adminPassword, initialPlanName }` | - | Chỉ làm trên web portal, không làm trên mobile (chốt 22/10/2026) |

`AuthResponse` (tên trường snake_case theo `@JsonProperty`): `{ access_token, refresh_token, token_type: "Bearer", expires_in, user_info: { id, email, full_name, phone, avatar, role, tenant_id, subdomain } }`.

JWT payload: `{ sub: "<userId>", role, tenantId?, tenant_id?, subdomain?, iat, exp }` (HS256, hạn 24h; refresh token hạn 7 ngày, lưu ở Redis). Không có email.

Đường không cần token (`permitAll`): `login`, `register`, `refresh`, `forgot-password`, `reset-password`, `/api/v1/tenants/onboarding`.

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
| Đăng ký khách (A-05) | Đã có `POST /api/v1/auth/register` (mục 1). Còn chờ: gắn khách vào cửa hàng theo `subdomain`; OTP xác minh email nếu cần | ✅ (không OTP) |
| Cửa hàng của khách (C-00) | `GET /api/customer/shops` → `[{ tenantId, name, logoUrl, tier, points }]`; `GET /api/storefront/shops/{shopCode}` (xem trước); `POST /api/customer/shops` `{ shopCode }` (tham gia) | ⚪ (mock) |

**Nhiều cửa hàng:** mọi API `/api/customer/*` và `/api/storefront/*` nhận cửa hàng đang xem qua header `X-Tenant-Id` (đề xuất). JWT của khách không mang `tenantId` cố định.

## 4. API app đang chờ backend (gửi team backend)

Cập nhật 22/10/2026, bản app v0.1.0. Mỗi dòng: màn hình dùng API, endpoint **đề xuất** (backend có thể đổi tên, chỉ cần báo lại), và repository mock đang thay thế trong app. Khi backend có API, app chỉ thêm `…RemoteRepository` cùng interface, màn hình không đổi.

Quy ước chung: response `{ success, message, data, timestamp }`, enum viết HOA, phân trang kiểu Spring (đầu file), header `Authorization: Bearer <JWT>`.

### 4.1. Xác thực

| Màn hình | Endpoint đề xuất | Mock đang thay thế |
|---|---|---|
| A-02 Đăng nhập (khách) | `POST /api/auth/login` trả thêm role `CUSTOMER` (hoặc `POST /api/customer/auth/login`) | `AuthMockRepository` (tài khoản demo) |
| A-05 Đăng ký khách | Đã nối `POST /api/v1/auth/register` (`RegistrationRemoteRepository`). Chờ BE gắn khách vào cửa hàng theo `subdomain` | - |
| A-05 OTP | `POST /api/customers/verify-email` `{ email, otp }`, `POST /api/customers/resend-otp` `{ email }` (BE chưa có OTP; app bỏ bước này khi dùng BE thật) | `RegistrationMockRepository.verifyEmail`, `.resendOtp` (chỉ chế độ mock) |

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

1. ~~Thêm role `CUSTOMER` vào login~~: đã có ở BE `develop` (`/api/v1/auth/login`).
2. **Trả DTO thay vì entity** (README backend đã nêu nguyên tắc này) để tránh lộ trường như `appSecretEncrypted`.
3. Giữ định dạng lỗi `{ success: false, message }` cho mọi lỗi (kể cả 401/403 từ Spring Security) để app hiển thị đúng.
4. Cấu hình CORS không cần cho mobile, nhưng cần cho web portal sau này.
5. **Trả kèm `errorCode`** trong body lỗi (`{ success: false, message, errorCode }`). `BusinessException` đã có mã (`INVALID_CREDENTIALS`, `ACCOUNT_TEMP_LOCKED`, `ACCOUNT_DISABLED`) nhưng `GlobalExceptionHandler` chưa gửi ra, nên màn A-02 đang phải đoán loại lỗi qua nội dung `message` (xem `lib/features/auth/domain/auth_failure.dart`).
6. **Khóa tenant khi đăng nhập (FR-003):** app chờ `403` với `errorCode: TENANT_LOCKED` (mock đang giả lập đúng như vậy).
7. **Khách dùng nhiều cửa hàng:** tách tài khoản khách khỏi tenant (bảng nối khách–cửa hàng), thêm các API ở mục 3 (đăng ký + OTP, danh sách/tham gia cửa hàng) và header `X-Tenant-Id` cho API khách.
8. **Dự báo M-51, "Nên nhập thêm":** API dự báo trả `recommendedReorderQty` theo từng ngày. App đang hiển thị **giá trị lớn nhất trong 7 ngày** (`summarizeForecast` ở `lib/features/ai_insights/domain/demand_forecast.dart`). Cần backend xác nhận: đó là số nên nhập cho cả 7 ngày, hay phải cộng dồn, hay nên trả sẵn một con số tổng.
