# Hợp đồng API (màn hình ↔ backend)

Backend: [Smart-Omni/SmartOmni_BE](https://github.com/Smart-Omni/SmartOmni_BE), nhánh `develop`, đối chiếu ở commit `f9495df` (Merge PR #44; thêm `/api/v1/tenants/subscription`, `SubscriptionController` ở tenant-service). Lần đối chiếu trước: `361e8b5` (thêm `/api/v1/loyalty`), `9558375` (Merge PR #35 `fix/auth-b1-b5`), `3eb89ec` (tài liệu BE: `TAILIEU_SUA_LOI_SHOPEE_VA_NEN_TANG.md`), `4cae7a2`, `fda1ab2`.

- Mọi request đi qua **Nginx Gateway** `:8080`, header `Authorization: Bearer <JWT>` (trừ login/quên mật khẩu).
- Response chuẩn: `{ "success": bool, "message": string?, "code": string?, "data": T, "timestamp": ISO-8601 }`. `code` là mã lỗi ổn định (từ `4cae7a2`), vd. `TOKEN_REVOKED`, `FEATURE_NOT_AVAILABLE`, `SKU_LIMIT_EXCEEDED`, `VALIDATION_ERROR`. Từ `9558375` mọi 401 đều có `code`: `TOKEN_EXPIRED`, `TOKEN_REVOKED` hoặc `UNAUTHORIZED`.
- Phân trang có **2 kiểu** (app đọc cả hai ở `PageResult.fromJson`):
  - `Page` mặc định của Spring (products, inventory, orders): `?page=0&size=20&sort=createdAt,desc` (inventory không nhận `sort`, BE tự sắp theo `skuId`) → `data: { content: [...], totalElements, totalPages, number, size, first, last, … }`.
  - `PageResponse` snake_case (`/api/v1/users`): `?page=0&size=10&sortBy=createdAt&sortDir=desc` → `data: { content, total_elements, total_pages, page_number, page_size, first, last, has_next, has_previous }`.
- Enum gửi/nhận viết HOA: `SHOPEE`, `TIKTOK_SHOP`, `PENDING`, `TO_SHIP`...

Chú thích cột **Trạng thái**:
- ✅ **Thật** - backend đã có, app gọi API khi `USE_MOCK=false`.
- 🟡 **Mock** - backend chưa có API, app luôn dùng dữ liệu mẫu (màn hình có dải "Dữ liệu mẫu").
- ⚪ **Chưa làm** - chưa có màn hình (mục "Sắp có").
- 🔜 **Đang nối** - BE đã có API (`fda1ab2`), app đang nối trong nhánh `feature/api-be-1111`; tới khi xong vẫn dùng mock.

## 0. Tình trạng nối API (BE `develop` @ `f9495df`)

Khi `USE_MOCK=false`, chức năng nào gọi API thật được chọn ở `lib/app/config/api_availability.dart` (`connectedFeatures`); chức năng chưa nối được dùng Mock và hiện `SoMockBanner`. Mọi đường dẫn API nằm ở `lib/core/network/api_paths.dart`. BE sửa xong: sửa đường dẫn (nếu đổi) rồi thêm chức năng vào `connectedFeatures`.

### ✅ Nối được ngay

| Màn | API BE | Ghi chú |
|---|---|---|
| A-02 Đăng nhập | `POST /api/v1/auth/login` | Đọc dạng mới: vai trò nằm trong `userInfo` |
| Đăng xuất | `POST /api/v1/auth/logout` | |
| A-03 Quên mật khẩu | `POST /api/v1/auth/forgot-password` | |
| A-04 Đặt lại mật khẩu | `POST /api/v1/auth/reset-password` | Gửi thêm ô nhập lại mật khẩu |
| Tự gia hạn phiên | `POST /api/v1/auth/refresh` | Không bị đá ra khi token hết hạn |
| A-05 Đăng ký khách | `POST /api/v1/auth/register` | Bỏ OTP khi dùng BE thật; mã cửa hàng gửi làm `subdomain`, BE gắn khách vào cửa hàng đó. Sai mã: 404 `STORE_NOT_FOUND` → "Không tìm thấy cửa hàng" dưới ô mã |
| M-50 Thông tin tài khoản | `GET /api/v1/users/me`, `GET /api/v1/tenants/me` | Tên, email, tên cửa hàng thật |
| Đổi mật khẩu (C-40, M-50 đang ghi "Sắp có") | `POST /api/v1/auth/change-password` | Bật lên được vì API đã có |
| M-30, M-31, M-32 Sản phẩm | `GET /api/v1/products`, `GET /api/v1/products/skus?productIds=…`, `GET /api/v1/products/{id}`, `GET /api/v1/products/{id}/skus`, `POST /api/v1/products` | SKU của cả danh sách lấy một lần ở `/products/skus?productIds=1,2,3` (danh sách rỗng thì không gọi). BE không trả link sàn: ẩn chấm kênh ở M-30, ẩn nhóm "Liên kết sàn" ở M-31. Nhãn tồn kho ẩn tới khi nối tồn kho. Gói Free quá 100 SKU: 400 `SKU_LIMIT_EXCEEDED`, hiện ở banner |
| M-20, M-21 Đơn hàng, hoàn/trả | `GET /api/v1/orders`, `GET /api/v1/orders/{id}`, `PATCH /api/v1/orders/{id}/status?status=TO_SHIP`, `POST /api/v1/returns` | M-21 hiện ngay dữ liệu từ danh sách, sản phẩm tải ở `GET /orders/{id}` (đang tải: khung xám; lỗi: "Không tải được danh sách sản phẩm." + Thử lại). BE chưa điền `skuCode`, `productName` nên tạm hiện "SKU #id". App chỉ cho chuyển sang `TO_SHIP` (chặn cả ở repository). Hộp thư (còn mock) dùng đơn mẫu riêng và không mở M-21 từ thẻ đơn |
| T-10 Kết nối sàn | `GET /api/v1/marketplace-connections/{shopee,tiktok-shop}`, `POST …/authorization`, `POST …/callback`, `POST …/disconnect`, `PATCH …/shopee/settings` | Kết nối qua OAuth (xem "Cách thử OAuth T-10"), ngắt kết nối, công tắc tự nhập Shopee. Công tắc tự nhập TikTok vẫn là mẫu (BE chưa có). Staff không thấy nút Kết nối / Ngắt kết nối |
| M-51 Dự báo AI | `GET /api/v1/ai/forecast/{skuId}?from=<hôm nay>&days=14` | BE lọc và sắp xếp; app vẫn sắp xếp, chỉ lấy từ hôm nay, tối đa 7 ngày; dòng không đọc được ngày bị bỏ. Danh sách SKU để chọn lấy từ tồn kho (M-40). Chỉ gói Pro (403 `FEATURE_NOT_AVAILABLE`) |
| M-40 Tồn kho | `GET /api/v1/inventory`, `POST /api/v1/inventory/{skuId}/adjust` | Đọc thẳng `InventoryItemDto` (mã SKU, tên sản phẩm, `availableQuantity`, đủ SKU kể cả tồn 0), giữ thứ tự BE. Tên biến thể ghép từ danh sách sản phẩm (dùng chung M-30). Dòng tồn không khớp SKU: BE trả `SKU-<id>` / "Unknown Product". Nhãn tồn ở M-30, M-31 hiện lại |
| T-20 Nhân viên | `GET /api/v1/users`, `POST /api/v1/users`, `PATCH /api/v1/users/{id}/status` | Danh sách (chủ cửa hàng và role `STAFF`), thêm (họ tên + email + mật khẩu tạm, role `STAFF`), khóa / mở khóa. App chặn chủ cửa hàng tự khóa (BE không chặn) |
| C-20 Điểm & hạng (khách) | `GET /api/v1/loyalty/me`, `GET /api/v1/loyalty/me/claims`, `GET /api/v1/loyalty/me/vouchers` | Chỉ role `CUSTOMER`. Thẻ hạng dùng `tier`, `pointsToNextTier` của BE (khớp `LoyaltyRules`: 500 / 1.000 / 1.500, 1 điểm / 1.000 ₫); `tier` lạ hoặc thiếu thì tự tính theo `totalPoints`. Lịch sử hiện "Đơn #<orderId>", không nhãn sàn (L3). Voucher ẩn sàn và hạn dùng (L4); nút "Sao chép" chỉ có khi có `code`; `status` khác `issued` hiện nhãn trung tính. Xem "Loyalty: L1–L6" |
| T-40 Gói dịch vụ (chỉ Tenant Admin) | `GET /api/v1/tenants/subscription/status`, `GET …/invoices`, `POST …/checkout`, `GET …/orders/{orderCode}/status` | Thẻ gói theo `/status` (tên, trạng thái, hạn, số ngày còn lại); hóa đơn theo `/invoices`. Nút Thanh toán / Nâng cấp PRO chỉ khi `FREE`, `EXPIRED` hoặc `canRenewEarly`: sheet VietQR (ảnh `qrUrl`, STK, ngân hàng, chủ TK, nội dung, số tiền, đếm ngược `expiresAt`), hỏi trạng thái đơn mỗi 5 giây khi sheet mở; `PAID` → đóng sheet, tải lại `/status`, `/invoices`, `tenants/me`. Hạn mức và mức đã dùng vẫn mẫu (P3). `simulate-pay` chỉ bản dev (P1). Xem "Gói dịch vụ: P1–P7" |

### 🆕 Thay đổi ở `9558375` (app đã xử lý)

Đọc code BE, chưa chạy với BE thật.

| Thay đổi | BE `9558375` | App |
|---|---|---|
| Bỏ role `MANAGER` | Migration V21 đổi `users.role` manager → staff, lời mời chỉ còn `STAFF`; `POST /api/v1/users` với role `MANAGER` trả 400 `INVALID_ROLE`. JWT cũ mang `MANAGER` bị 401 `TOKEN_REVOKED`; refresh đọc role từ DB nên token mới mang `STAFF` | T-20 thêm nhân viên gửi `role: "STAFF"`, danh sách bỏ `MANAGER`. `UserRole.fromBackend` vẫn nhận `MANAGER` (JWT cũ) và coi là nhân viên. Mock đổi sang `STAFF` |
| 401 có mã | `JwtAuthenticationFilter`: token hết hạn → 401 `TOKEN_EXPIRED` (trước là 403 body rỗng), bị thu hồi → 401 `TOKEN_REVOKED`, thiếu / sai token → 401 `UNAUTHORIZED` (`JsonAuthenticationEntryPoint`) | `TOKEN_EXPIRED`, `UNAUTHORIZED`: refresh rồi gọi lại; refresh thất bại → về đăng nhập, câu "hết hạn" (không phải "bị thu hồi"). Logic cũ đã đúng, chỉ thêm test. Vẫn refresh trước hạn theo `exp` |
| 403 `STAFF_NO_TENANT` | Nhân viên chưa thuộc cửa hàng (`tenantId` null) vẫn đăng nhập được, nhưng mọi API ngoài `/users/me*` và `/auth/*` trả 403 `STAFF_NO_TENANT` | A-02: role `STAFF` mà `tenant_id` null thì không vào app: gọi `POST /auth/logout` bằng access token vừa nhận (BE xóa luôn refresh token; chạy nền, lỗi bỏ qua), không lưu token, banner "Tài khoản nhân viên chưa thuộc cửa hàng nào. Liên hệ chủ cửa hàng." API trả 403 này thì hiện cùng câu |

### ✅ BE đã sửa ở `3eb89ec` (trước đây trong bảng lỗi gửi BE)

Mã C2–C8, B4, B5 theo `TAILIEU_SUA_LOI_SHOPEE_VA_NEN_TANG.md` của BE. Đọc code BE, chưa chạy với BE thật.

| Mã | Lỗi cũ | BE `3eb89ec` | App |
|---|---|---|---|
| C4 | M-30 N+1: mỗi sản phẩm một lần gọi `/{id}/skus` | `GET /api/v1/products/skus?productIds=1,2,3` → `List<ProductSku>` (lọc tenant) | Đã dùng: 1 request cho cả danh sách |
| C2, C8 | M-21 không có sản phẩm của đơn | `GET /api/v1/orders/{id}` → `OrderDetailDto` kèm `items: [OrderItemDto { id, skuId, skuCode, productName, quantity, unitPrice, subtotal, imageUrl }]` | Đã dùng (xem dòng lỗi mới về `skuCode`/`productName`) |
| C5, C8 | M-40 thiếu SKU chưa đặt tồn, thiếu tên | `Page<InventoryItemDto> { skuId, skuCode, productName, quantityOnHand, reservedQuantity, availableQuantity }`, đủ SKU (tồn 0), sắp theo `skuId` | Đã dùng; bỏ `sort` |
| C6 | M-51 trả ngày đã qua, không sắp xếp | `?from=yyyy-MM-dd&days=`, `ORDER BY forecast_date ASC`, mặc định từ hôm nay | Đã dùng `from=<hôm nay>&days=14` |
| - | A-05 khách không gắn cửa hàng | `register` gắn theo `subdomain` (hoặc `tenant_id`); sai mã 404 `STORE_NOT_FOUND`, cửa hàng khóa 403 `TENANT_LOCKED` | Đã dùng |
| - | A-05 tra mã cửa hàng trả 404 | `c9caf20` thêm RLS cho đọc công khai tenant | Chưa chạy lại; ô mã vẫn chỉ kiểm định dạng khi dùng BE thật |
| B4 | App Key luôn 400 | Endpoint `POST /api/v1/marketplace-connections` đánh dấu `@Deprecated`, thông báo chỉ sang OAuth | Đã bỏ form App Key (cả mock) |
| C7 | Không có `autoImportProducts` | `ShopeeConnectionDto.autoImportProducts` + `PATCH /api/v1/marketplace-connections/shopee/settings` `{ auto_import_products }` | Đã dùng cho Shopee; TikTok vẫn mẫu |
| B5 | OAuth không quay về app | `POST /api/v1/marketplace-connections/shopee/authorization` nhận `redirect_uri` (whitelist `smartomni://*`, localhost, `*.smartomni.vn`) → `authorizationUrl` | Đã dùng: `redirect_uri = smartomni://oauth/shopee` |

### ✅ BE đã sửa ở `4cae7a2` (trước đây trong bảng lỗi gửi BE)

Đọc code BE, chưa chạy với BE thật. Kế hoạch sửa của BE: `specs/A1…A5` trong repo BE.

| Mã | Lỗi cũ | BE `4cae7a2` | Ảnh hưởng tới app |
|---|---|---|---|
| A1 | Khóa user xóa refresh token theo mẫu `…<id>*` (xóa nhầm user khác) | `UserRefreshTokenRevoker` xóa đúng 2 key của user đó; dùng cho cả khóa và đổi quyền | Không cần sửa app |
| A2 | Nhân viên bị khóa vẫn dùng access token cũ tới 24 giờ | JWT mang `tokenVersion`; `JwtAuthenticationFilter` so với Redis ở mọi service. Khóa / đổi quyền tăng phiên bản → 401 `TOKEN_REVOKED` ngay request kế tiếp | App báo "Phiên đăng nhập đã bị thu hồi…" (xem "Hành vi mới") |
| A3 | `adjust`/`restock` không lọc tenant, tự tạo dòng cho SKU bất kỳ | Tìm theo tenant + SKU; chỉ tạo dòng tồn khi SKU thuộc đúng tenant (sai → 404) | SKU chưa có dòng tồn vẫn đặt tồn được ngay |
| A4 | `updateStatus`, `createReturnRequest` không lọc tenant | `findByIdAndTenantId`; đơn / hoàn trả của tenant khác → 404 | Không cần sửa app |
| A5 | Không chặn chuyển trạng thái đơn sai | Nhân viên chỉ được `PENDING → TO_SHIP`, sai thì 409 `INVALID_ORDER_STATUS_TRANSITION`; webhook sàn có luật riêng | App vẫn giữ chặn ở repository (không gửi request sai) |
| Mã lỗi | Body lỗi không có mã | `ApiResponse` có thêm `code` (`VALIDATION_ERROR`, `UNAUTHORIZED`, `INTERNAL_ERROR` và mã của từng `BusinessException`). Lỗi 500 không còn lộ nội dung exception | App đọc `code` vào `ApiException.code` |

### 🆕 Hành vi mới ở `4cae7a2` (app đã xử lý)

| Màn | API | BE trả | App |
|---|---|---|---|
| Mọi màn cần đăng nhập | mọi API | 401 `{ code: "TOKEN_REVOKED", message: "Phiên đăng nhập đã bị thu hồi" }` khi tài khoản bị khóa hoặc đổi quyền; refresh token cũng bị thu hồi nên `refresh` trả 401 `INVALID_TOKEN` | Refresh thất bại sau `TOKEN_REVOKED` → đăng xuất, màn đăng nhập hiện "Phiên đăng nhập đã bị thu hồi (tài khoản bị khóa hoặc đổi quyền). Vui lòng đăng nhập lại." Hết phiên khác giữ câu cũ. Giới hạn: refresh trước hạn (token sắp hết `exp`) không thấy `TOKEN_REVOKED` nên vẫn báo "hết hạn" |
| M-51 Dự báo AI | `GET /api/v1/ai/forecast/{skuId}` | 403 `{ code: "FEATURE_NOT_AVAILABLE", message: "Tính năng AI chỉ khả dụng cho gói Pro." }` khi cửa hàng không ở gói PRO (`AiSubscriptionPlanFilter`) | Biết trước gói qua `planType` của `tenants/me` (khác `PRO`) → hiện ngay "Dự báo AI chỉ có ở gói Pro", không mở sheet chọn SKU, không gọi dự báo. Chưa biết gói → gọi như thường, gặp 403 này thì hiện cùng trạng thái kèm message BE, không có "Thử lại" |
| M-32 Tạo sản phẩm | `POST /api/v1/products` | 400 `{ code: "SKU_LIMIT_EXCEEDED", message: "Gói Free chỉ hỗ trợ tối đa 100 SKU." }` khi gói FREE vượt 100 SKU | Hiện message ở banner "Chưa tạo được sản phẩm" (không phải dưới ô Mã SKU). Trùng mã SKU (400 `BUSINESS_ERROR`) vẫn hiện dưới ô |

### BE mới có, app chưa dùng

- `3eb89ec`: `POST /api/v1/orders` (`CreateManualOrderRequest`, `source = MANUAL`) tạo đơn để thử ở môi trường dev; `POST /api/v1/returns/{id}/inspection` (kho kiểm hàng hoàn trước khi nhập lại kho); lời mời nhân viên `POST/GET /api/v1/users/invitations`, `DELETE /api/v1/users/invitations/{id}`, `GET /api/v1/users/me/invitations`, `POST /api/v1/users/me/invitations/{id}/accept` (người nhận thành role `STAFF`); OAuth và cài đặt Shopee ở trên (B5, C7).
- `POST /api/v1/tiktok/connect` (`TiktokConnectController`), body `TiktokConnectRequest { code, state, error, shopId, shopName }`: nhận kết quả OAuth của TikTok Shop. App chưa dùng.
- `TenantProfileResponse` có thêm `tenantUrl`.

### 🔜 BE đã sửa (`9e7c4da`), app đang nối

Trước `fda1ab2`, các đường dưới đây trả 404 (controller còn ở `/api/...`) hoặc 403 (T-20 chỉ cho `TENANT_OWNER`). Bước nào xong thì dòng đó chuyển lên bảng "Nối được ngay".

| Màn | API BE | Bước |
|---|---|---|
| M-22 In vận đơn | `/api/v1/marketplace-connections/shopee/...` | Để sau buổi review |

### Loyalty (BE `361e8b5`): L1–L6

Đọc code BE (`LoyaltyController`, `LoyaltyCustomerService`, `LoyaltyRewardService`, `LoyaltyTierCalculator`, `dto/loyalty`), chưa chạy với BE thật. JSON camelCase như DTO Java (order-service không cấu hình snake_case), `Instant` là chuỗi ISO-8601, `BigDecimal` là số. Mọi endpoint lấy tenant và khách từ JWT (`TenantContext`), không đọc header `X-Tenant-Id`; thiếu thì 403 `TENANT_MISSING` / `TENANT_OR_USER_MISSING`.

DTO app đọc:
- `LoyaltyProfileDto` (`/me`): `{ customerId, tenantId, totalPoints, tier, nextTier, nextTierThreshold, pointsToNextTier }`. `tier` luôn là một trong `Standard`, `Silver`, `Platinum`, `Diamond` (hạng thấp nhất là `"Standard"`, không `null`); hạng cao nhất có `nextTier`, `nextTierThreshold` = `null`, `pointsToNextTier` = 0. Khách chưa có tài khoản điểm → 0 điểm, `Standard`.
- `LoyaltyClaimDto` (`/me/claims`, mới trước cũ, không phân trang): `{ id, orderId, customerId, eligibleAmountVnd, pointsAwarded, claimedAt }`.
- `LoyaltyRewardRequestDto` (`/me/vouchers`, mới trước cũ, không phân trang): `{ id, tenantId, campaignId, campaignName, discountPercent, customerId, requestKey, status, code, externalVoucherId, failureReason, requestedAt, issuedAt, updatedAt }`. `status` chữ thường `pending` / `issued` / `failed`; chỉ `issued` mới có `code`.

| Mã | Màn | API | Lỗi | Ảnh hưởng tới app / đề xuất |
|---|---|---|---|---|
| L1 | T-30 Phát voucher, nút đổi điểm lấy voucher | `/api/v1/loyalty/campaigns`, `POST /api/v1/loyalty/me/reward-requests` | Mô hình voucher chưa chốt: BE làm theo chiến dịch (`required_points`, `quantity`, `discountPercent`, khách tự xin), còn T-30 phát theo đợt cho danh sách khách (sàn, mức giảm, đơn tối thiểu, hạn dùng) | T-30 giữ mock + `SoMockBanner`. App không thêm tính năng đổi điểm lấy voucher. Cần chốt một mô hình rồi mới nối |
| L2 | C-30 Claim đơn | `POST /api/v1/loyalty/claims` `{ orderId, totalAmount }` | Đòi `orderId` nội bộ và tổng tiền khớp tuyệt đối, khách chỉ biết mã đơn trên sàn | C-30 giữ mock + `SoMockBanner` (`LoyaltyRemoteRepository.claimOrder` chuyển sang mock). Đề xuất nhận `{ platform, orderCode }` (mã đơn trên sàn) và tự tra đơn, tiền |
| L3 | C-20 Lịch sử điểm | `GET /api/v1/loyalty/me/claims` | Không có mã đơn trên sàn và sàn | App tạm hiện "Đơn #<orderId>" (id nội bộ), ẩn nhãn sàn. Đề xuất thêm `platformOrderCode`, `platform` |
| L4 | C-20 Voucher | `GET /api/v1/loyalty/me/vouchers` | Không có sàn dùng voucher và hạn dùng | App ẩn nhãn sàn và hạn dùng. Đề xuất thêm `platform`, `expiresAt` (vd. lấy từ chiến dịch / voucher trên sàn) |
| L5 ✅ Đã rõ | C-20 Thẻ hạng | `GET /api/v1/loyalty/me` | Không phải lỗi. Câu hỏi: hạng thấp nhất BE trả `null` hay tên khác "Standard"? | `LoyaltyTierCalculator` luôn trả `"Standard"` (kể cả khách chưa có tài khoản điểm: 0 điểm), không trả `null`. App map về `LoyaltyTier.standard`; phòng hờ `tier` thiếu / lạ thì tự tính theo `totalPoints` |
| L6 | C-00 đổi cửa hàng → C-20 | mọi `/api/v1/loyalty/me*` | Tenant lấy từ JWT nên chỉ xem được cửa hàng đã đăng ký; khách không có cách xem điểm ở cửa hàng khác | C-00 còn mock: đổi cửa hàng ở C-00 không đổi dữ liệu C-20 khi dùng BE thật. Cần quyết định: một tài khoản mỗi cửa hàng (bỏ C-00) hay tách khách khỏi tenant (mục 4.5 ý 7) |

### Gói dịch vụ (BE `f9495df`): P1–P7

Đọc code BE (`SubscriptionController`, `SubscriptionServiceImpl`, `dto/Subscription*`, `SepayVietQrHelper`, `SecurityConfig` của tenant-service), chưa chạy với BE thật. JSON camelCase; `LocalDate` là `yyyy-MM-dd`, `Instant` là ISO-8601, `BigDecimal` là số. Tenant lấy từ JWT. Mã lỗi nằm ở khóa `code` của `ApiResponse`.

DTO app đọc:
- `SubscriptionSummaryResponse` (`/status`): `{ planName, pro, status, periodStart, periodEnd, daysRemaining, canRenewEarly, currentInvoiceId }`. Field Java là `boolean isPro`, Lombok sinh getter `isPro()` nên Jackson ghi khóa **`"pro"`** (test controller của BE cũng đọc `$.data.pro`); app đọc cả `"pro"` lẫn `"isPro"`. `status`: `FREE` / `ACTIVE` / `EXPIRING_SOON` (còn ≤ 5 ngày) / `EXPIRED`. Gói FREE: ngày `null`, `daysRemaining` 0.
- `SubscriptionInvoiceDto` (`/invoices`, mới trước cũ): `{ id, invoiceNumber ("INV-<id>"), paymentCode, gatewayTransactionId, paymentMethod, period ("yyyy-MM-dd - yyyy-MM-dd"), amount, status, dueDate, paidAt, createdAt }`.
- `SubscriptionCheckoutResponse` (`POST /checkout`, không body): `{ orderCode ("PRO" + 4 số tenant + 5 số payment), amount, qrUrl (vietqr.app), accountNumber, bankId, accountHolder, memo (= orderCode), planName ("PRO"), expiresAt (+15 phút) }`. PRO còn > 5 ngày: 400 `SUBSCRIPTION_EARLY_RENEWAL_TOO_EARLY` → app hiện "Gói PRO còn hơn 5 ngày hiệu lực. Bạn chỉ gia hạn được khi còn từ 5 ngày trở xuống.", không có nút tạo lại.
- `SubscriptionOrderStatusResponse` (`/orders/{orderCode}/status`): `{ orderCode, status (PENDING/PAID/FAILED/EXPIRED), planName, paidAt }`. Mã sai / không thuộc tenant → `FAILED`.

| Mã | Màn | API | Lỗi | Ảnh hưởng tới app / đề xuất |
|---|---|---|---|---|
| P1 | T-40 sheet thanh toán | `POST /api/v1/tenants/subscription/orders/{orderCode}/simulate-pay` | Ai đăng nhập cũng gọi được, không tắt theo môi trường: tự lên PRO, sinh hóa đơn PAID mà không trả tiền | Nút "Giả lập đã thanh toán" chỉ có ở flavor dev (`AppConfig.allowsPaymentSimulation`); staging / prod không có. Luồng thật chỉ chờ webhook SePay và hỏi trạng thái đơn, không phụ thuộc API này. Đề xuất: chỉ bật API ở profile dev |
| P2 | T-40 | mọi `/api/v1/tenants/subscription/*` | Không kiểm role (chỉ cần `authenticated`): STAFF xem gói, hóa đơn và tạo được phiên thanh toán | App chỉ cho Tenant Admin mở T-40 (`resolveRedirect`). Đề xuất chỉ cho `TENANT_ADMIN` |
| P3 | T-40 Mức đã dùng | `GET …/status` | Thiếu giới hạn (SKU, kết nối sàn, dung lượng ảnh), mức đã dùng và giá gói | Phần "Mức đã dùng" giữ dữ liệu mẫu + `SoMockBanner` riêng phần đó. Giá chỉ biết khi checkout (`amount`). Ngoài danh sách: BE cũng chưa có API đổi / hạ gói, app không hiện nút "Đổi gói" |
| P4 | T-40, M-51 | `SubscriptionServiceImpl.isProTenant` | Coi `planId == 2` là PRO (hardcode), trước cả khi tra tên gói | Không ảnh hưởng code app; dữ liệu gói đổi id thì `/status` sai. Đề xuất chỉ tra theo tên / mã gói |
| P5 | T-40 và M-51 | `GET …/subscription/status`, `GET /api/v1/tenants/me` | Shop PRO mà không có hóa đơn PAID (vd. đặt `plan_type = PRO` tay / seed) thì `/status` trả `FREE`, còn `/tenants/me` trả `planType: PRO` | T-40 hiện theo `/status` (FREE, có nút Nâng cấp PRO). M-51 vẫn theo `planType` của `/tenants/me`. Hai màn có thể lệch nhau tới khi BE thống nhất một nguồn |
| P6 | T-40 Hóa đơn | `GET …/invoices` | Chỉ trả hóa đơn `PAID` (checkout không tạo hóa đơn chờ) nên app không bao giờ có "Chưa thanh toán"; `period` là một chuỗi ghép `"yyyy-MM-dd - yyyy-MM-dd"`, không phải hai trường ngày | App tách `period` theo `" - "`; vẫn hiện nhãn "Chưa thanh toán" nếu BE sau này trả trạng thái khác `PAID`. Đề xuất `periodStart`, `periodEnd` riêng |
| P7 | T-40 sheet thanh toán | `POST …/checkout`, `GET …/orders/{code}/status` | `expiresAt` của mã QR là 15 phút, nhưng trạng thái đơn chỉ thành `EXPIRED` khi phiên tạo quá 24 giờ. Gọi checkout lại trong 15 phút dùng lại phiên cũ (cùng `orderCode`) nhưng trả `expiresAt` mới | Quá `expiresAt` mà vẫn `PENDING`: app hỏi trạng thái thêm một lần; `PAID` thì xử lý như thành công, còn lại báo "Mã đã hết hạn. Nếu bạn đã chuyển khoản, đừng chuyển lại - hệ thống sẽ ghi nhận trong vài phút, hãy tải lại trang Gói dịch vụ." + "Tạo mã mới", ngừng hỏi. Đề xuất trả `EXPIRED` theo đúng 15 phút |

### ❌ Chưa nối được: lỗi và nguyên nhân (gửi BE)

| Màn trong app | API | Lỗi | Nguyên nhân |
|---|---|---|---|
| M-10, M-60/61, T-50, C-00, C-10, C-11, C-12 | - | Chưa có API | BE chưa làm các chức năng này |
| T-30, C-30 | `/api/v1/loyalty/*` | Có API nhưng chưa dùng được | Xem L1, L2 ở "Loyalty: L1–L6" |
| Mọi màn cần đăng nhập | `POST /api/v1/auth/refresh` | Không phân biệt phiên bị thu hồi với hết hạn | API refresh nên trả mã riêng (vd. `TOKEN_REVOKED`) khi refresh token bị thu hồi do khóa/đổi quyền, để app phân biệt với hết hạn thường. Hiện trả 401 `INVALID_TOKEN` cho cả hai |
| M-21 Chi tiết đơn | `GET /api/v1/orders/{id}` | Sản phẩm không có mã SKU, tên | `OrderItemDto` khai báo `skuCode`, `productName` nhưng `OrderService.getOrderDetail` không điền (entity `OrderItem` chỉ có `skuId`), nên luôn `null`. App tạm hiện "SKU #<skuId>". Đề xuất điền từ `product_skus` + `products` |
| T-10 Công tắc tự nhập (TikTok) | `GET /api/v1/marketplace-connections/tiktok-shop` | Không có `autoImportProducts` | `3eb89ec` chỉ thêm cho Shopee (`ShopeeConnectionDto` + `PATCH …/shopee/settings`); `TiktokConnectionDto` chưa có. App giữ công tắc ở dạng mẫu cho cả hai sàn |
| Chạy thử | - | Không có sẵn tài khoản | BE chưa có dữ liệu demo. Phải tự tạo: mở cửa hàng qua web FE (`/api/v1/tenants/onboarding`) và đăng ký khách qua app |

### Cách thử OAuth T-10 trên máy ảo Android

Cần tài khoản Tenant Admin (Staff không thấy nút Kết nối). App chạy với BE thật (`USE_MOCK=false`).

**Shopee:** BE mặc định trỏ simulator `https://shopee-simulator.onrender.com` (`SHOPEE_BASE_URL`, `SHOPEE_AUTHORIZATION_URL`, partner id/key mẫu có sẵn trong `application.yml`). Máy ảo có Internet là mở được trang ủy quyền; Render bản miễn phí có thể đang ngủ nên lần đầu tải chậm.
1. T-10 → thẻ Shopee → **Kết nối**: trình duyệt mở trang của simulator.
2. Đồng ý: simulator chuyển về `smartomni://oauth/shopee?code=…&shop_id=…&state=…`, app gửi callback, thẻ thành "Đã kết nối" và hiện "Đã kết nối Shopee". Từ chối: "Bạn đã từ chối cấp quyền".
3. Bấm Back về app mà không qua trang của sàn: nút Kết nối dùng lại được, không báo lỗi.

**TikTok Shop:** BE chưa có giá trị mẫu (mục B10 của BE), phải tự chạy simulator TikTok ở máy (cổng `3090`) và cấu hình BE:
- `TIKTOK_APP_KEY`, `TIKTOK_APP_SECRET`, `TIKTOK_AUTHORIZATION_URL` (trang ủy quyền của simulator), cùng `TIKTOK_TOKEN_BASE_URL`, `TIKTOK_OPEN_API_BASE_URL` trỏ về simulator.
- `TIKTOK_ALLOWED_REDIRECT_URIS` phải có `smartomni://oauth/tiktok` (BE TikTok chỉ nhận đúng địa chỉ trong danh sách; `docker-compose.yml` của BE đã đặt sẵn giá trị này).
- Cho máy ảo gọi được `localhost:3090` của máy tính: `adb reverse tcp:3090 tcp:3090`.

Rồi làm như Shopee với thẻ TikTok Shop; deep link là `smartomni://oauth/tiktok?code=…&state=…`.

Thử deep link bằng tay (chỉ có tác dụng khi vừa bấm Kết nối, link lạ bị bỏ qua): `adb shell am start -a android.intent.action.VIEW -d "smartomni://oauth/shopee?error=access_denied&state=x"`.

## 1. Xác thực

| Màn hình | Method & Path | Body / Query | Trạng thái | Ghi chú |
|---|---|---|---|---|
| Đăng nhập | `POST /api/v1/auth/login` | `{ email, password }` → `AuthResponse` (dưới bảng) | ✅ | Role: `SUPER_ADMIN` (app từ chối), `ADMIN`, `TENANT_ADMIN`, `STAFF` (`tenant_id` null thì app từ chối, xem `STAFF_NO_TENANT`), `CUSTOMER`. `MANAGER` đã bỏ ở `9558375` |
| Gia hạn phiên | `POST /api/v1/auth/refresh` | `{ refresh_token }` → `AuthResponse` | ✅ | BE xoay vòng refresh token: luôn lưu token mới. App refresh trước khi gửi nếu `exp` còn < 30 giây, và khi gặp 401 (gọi lại request một lần). 401 có `code: TOKEN_REVOKED` mà refresh thất bại → báo phiên bị thu hồi; `TOKEN_EXPIRED` / `UNAUTHORIZED` → báo hết hạn |
| Đăng xuất | `POST /api/v1/auth/logout` | header `Authorization` | ✅ | BE blacklist access token, xóa refresh token. Lỗi vẫn xóa token ở máy |
| Quên mật khẩu | `POST /api/v1/auth/forgot-password` | `{ email }` | ✅ | |
| Đặt lại mật khẩu | `POST /api/v1/auth/reset-password` | `{ token, new_password, confirm_password }` (6–100 ký tự) | ✅ | |
| Đăng ký khách (A-05) | `POST /api/v1/auth/register` | `{ email, password (6–100), full_name, phone, subdomain }` → `AuthResponse` (201) | ✅ | Không có OTP: vào thẳng app. Ô "Mã cửa hàng" chỉ kiểm `^[a-z0-9-]{3,30}$` (chữ thường) rồi gửi làm `subdomain`; BE gắn khách vào cửa hàng đó, sai mã thì 404 `STORE_NOT_FOUND` ("Không tìm thấy cửa hàng" dưới ô mã). Email trùng: 409. Mock vẫn có OTP |
| Hồ sơ (M-50, C-40) | `GET /api/v1/users/me` | → `UserProfileResponse` (snake_case): `{ id, email, full_name, phone, avatar, role, status, tenant_id, subdomain, created_at, updated_at }` | ✅ | Thẻ hồ sơ hiện họ tên, email |
| Tên cửa hàng, gói (M-50, M-51) | `GET /api/v1/tenants/me` | → `TenantProfileResponse` (camelCase): `{ id, companyName, subdomain, tenantUrl, status, planType, …, storefront: { storeName, logoUrl, … } }` | ✅ | Chỉ gọi khi có `tenant_id`. Tên = `storefront.storeName`, trống thì `companyName`. `planType` (vd. `PRO`, `FREE`) quyết định M-51 có khóa sẵn không. Lỗi thì thẻ vẫn hiện tên, email |
| Đổi mật khẩu (C-40) | `POST /api/v1/auth/change-password` | `{ current_password, new_password (6–100), confirm_password }` | ✅ | Cần token. Lỗi 400 kèm `message` (sai mật khẩu hiện tại / trùng / không khớp). BE thu hồi refresh token nên app đăng xuất ngay, báo "Đã đổi mật khẩu, vui lòng đăng nhập lại." |
| Đăng ký tenant | `POST /api/v1/tenants/onboarding` | `{ businessName, subdomain, adminEmail, adminPassword, initialPlanName }` | - | Chỉ làm trên web portal, không làm trên mobile (chốt 22/10/2026) |

`AuthResponse` (tên trường snake_case theo `@JsonProperty`): `{ access_token, refresh_token, token_type: "Bearer", expires_in, user_info: { id, email, full_name, phone, avatar, role, tenant_id, subdomain } }`.

JWT payload: `{ sub: "<userId>", role, tenantId?, tenant_id?, subdomain?, iat, exp }` (HS256, hạn 24h; refresh token hạn 7 ngày, lưu ở Redis). Không có email.

Đường không cần token (`permitAll`): `login`, `register`, `refresh`, `forgot-password`, `reset-password`, `/api/v1/tenants/onboarding`.

## 2. Merchant (Staff + Tenant Admin)

| Màn hình | Method & Path | Body / Query | Trạng thái | Repository |
|---|---|---|---|---|
| Tổng quan | - | - | 🟡 | `dashboardSummaryProvider` |
| Danh sách đơn | `GET /api/v1/orders?page=0&size=20&sort=createdAt,desc` | → `Page<Order>` (camelCase: `platform, platformOrderId, status, customerName, customerPhone, shippingAddress, totalAmount, trackingNumber, slaDeadline, source, createdAt`) | ✅ | `OrdersRemoteRepository.fetchOrders` |
| Chi tiết đơn | `GET /api/v1/orders/{id}` | → `OrderDetailDto` (camelCase: các trường của `Order` + `shippingMethod, courierScannedAt, returnReason, rejectReason, restockStatus, items: [{ id, skuId, skuCode, productName, quantity, unitPrice, subtotal, imageUrl }]`) | ✅ | `OrdersRemoteRepository.getOrder`, `orderDetailProvider`. Chỉ gọi khi đơn hàng nối BE thật |
| Chuyển trạng thái đơn | `PATCH /api/v1/orders/{id}/status` | `?status=TO_SHIP` | ✅ | App chỉ cho `PENDING → TO_SHIP` |
| Ghi nhận hoàn/trả | `POST /api/v1/returns` | `CreateReturnRequest { orderId, reason }` → `ReturnRefund` (`REQUESTED`) | ✅ | |
| In vận đơn | - | - | 🟡 | Đề xuất `GET /api/v1/orders/{id}/shipping-label` (PDF); app dùng tem mẫu |
| Danh sách sản phẩm | `GET /api/v1/products?page=0&size=100&sort=createdAt,desc` | → `Page<Product>` (camelCase: `id, name, description, status: ACTIVE\|HIDDEN`); SKU của cả trang lấy một lần `GET /api/v1/products/skus?productIds=1,2,3` → `[ProductSku { id, productId, skuCode, variantName, basePrice }]`, ghép theo `productId` | ✅ | `ProductsRemoteRepository.listProducts`. Chỉ tải trang đầu 100 |
| Chi tiết sản phẩm | `GET /api/v1/products/{id}` + `GET /api/v1/products/{id}/skus` | - | ✅ | |
| Tạo sản phẩm | `POST /api/v1/products` | `CreateProductRequest { name, description?, skus: [{ skuCode, variantName?, basePrice? }] }` | ✅ | |
| Danh sách tồn kho | `GET /api/v1/inventory?page=0&size=500` | → `Page<InventoryItemDto>` (camelCase: `skuId, skuCode, productName, quantityOnHand, reservedQuantity, availableQuantity`), đủ SKU, sắp theo `skuId`; tên biến thể ghép từ danh sách sản phẩm | ✅ | `InventoryRemoteRepository` + `buildInventoryItems`. Chỉ tải trang đầu 500 |
| Đặt lại tồn | `POST /api/v1/inventory/{skuId}/adjust` | `?quantity=<số tồn MỚI>` | ✅ | BE **gán** số lượng, không cộng/trừ |
| Dự báo theo SKU | `GET /api/v1/ai/forecast/{skuId}` | `?from=yyyy-MM-dd&days=14` → `[DemandForecast { skuId, forecastDate (yyyy-MM-dd), predictedQuantity, recommendedReorderQty }]` | ✅ | |
| Gợi ý sản phẩm | `GET /api/v1/ai/recommendations/{skuId}` | | ⚪ | Chưa có màn hình |
| Cảnh báo AI | - | - | 🟡 | Đề xuất `GET /api/v1/ai/alerts` |
| Hộp thư CSKH | - | - | ⚪ | Chờ Message Service |

### Chỉ Tenant Admin

| Màn hình | Method & Path | Body / Query | Trạng thái | Ghi chú |
|---|---|---|---|---|
| Trạng thái kết nối sàn | `GET /api/v1/marketplace-connections/shopee`, `/tiktok-shop` → `ShopeeConnectionDto` / `TiktokConnectionDto` (`id, status, needsReconnect, shopId, shopName, connectedAt, …`; Shopee thêm `autoImportProducts`; chưa kết nối: `data: null`); ngắt: `POST …/{shopee,tiktok-shop}/disconnect` (chỉ Tenant Admin) | - | ✅ | `MISSING_SCOPE`/`REFRESH_FAILED`/`REVOKED`/`ERROR` = lỗi kết nối |
| Kết nối sàn (OAuth) | `POST {base}/authorization` → `{ authorizationUrl, expiresAt }`; `POST {base}/callback` → DTO kết nối. `{base}` = `/api/v1/marketplace-connections/shopee` hoặc `/tiktok-shop`. Chỉ Tenant Admin, callback phải dùng JWT của user đã bắt đầu | authorization: `{ "redirect_uri": "smartomni://oauth/shopee" }` (TikTok: `smartomni://oauth/tiktok`). callback Shopee (snake_case): `{ code, shop_id, state, error, error_description }`; TikTok (camelCase): `{ code, state, error, errorDescription }` | ✅ | Sheet "Kết nối <sàn>" → **Mở <sàn>**: app mở `authorizationUrl` ngoài app (`url_launcher`), nhận deep link `smartomni://oauth/<shopee\|tiktok>?code=&state=(&shop_id=)` hoặc `?error=&state=` (`app_links`), rồi gửi callback; thành công thì (Shopee) gửi `PATCH …/settings` theo công tắc trong sheet và hiện thẻ "xong". Chỉ xử lý khi đang chờ đúng sàn đó (lưu trong secure storage). Lỗi: `INVALID_REDIRECT_URI`, `*_STATE_INVALID` / `_EXPIRED` / `_REUSED`, `*_AUTHORIZATION_DENIED` (hoặc link có `error`) → câu tiếng Việt. Quay lại app không qua deep link = hủy, không báo |
| Tự nhập sản phẩm (Shopee) | `PATCH /api/v1/marketplace-connections/shopee/settings` | `{ "auto_import_products": true\|false }` | ✅ | TikTok chưa có API: công tắc vẫn mẫu |
| Quản lý Staff | `GET /api/v1/users?page=0&size=100&sortBy=createdAt&sortDir=asc` → `PageResponse<UserProfileResponse>` (snake_case); `POST /api/v1/users` `{ email, password (6–100), full_name (bắt buộc, ≤ 100), role: "STAFF" }` (409 `EMAIL_EXISTS`); `PATCH /api/v1/users/{id}/status` `{ status: ACTIVE\|DISABLED }` | | ✅ | `StaffRemoteRepository`. Chủ cửa hàng = role `TENANT_ADMIN`; chỉ hiện `TENANT_ADMIN`/`ADMIN`/`STAFF`. Chỉ tải trang đầu 100 người |
| Phát voucher | - | - | 🟡 | Phụ thuộc API tạo voucher của sàn; app dùng mock (`VoucherRepository`) |
| Gói SaaS | `GET /api/v1/tenants/subscription/status`, `GET …/invoices`, `POST …/checkout`, `GET …/orders/{orderCode}/status`; `POST …/orders/{orderCode}/simulate-pay` (chỉ bản dev) | checkout: không body | ✅ | `SubscriptionRemoteRepository`. Hạn mức còn mock (P3). Xem "Gói dịch vụ: P1–P7" |
| Hỗ trợ | - | - | 🟡 | Bảng `support_tickets` đã có, Nginx đã route `/api/support-tickets/`; app dùng mock (`SupportRepository`): danh sách + tạo (tiêu đề, mô tả) |

## 3. Customer

| Màn hình | API đề xuất cho backend | Trạng thái |
|---|---|---|
| Danh sách sản phẩm (Storefront) | `GET /api/storefront/products` (công khai theo tenant, chỉ sản phẩm ACTIVE + URL sàn) | 🟡 |
| Chi tiết sản phẩm | `GET /api/storefront/products/{id}` | 🟡 |
| Điểm & hạng | Đã nối `GET /api/v1/loyalty/me`, `GET /api/v1/loyalty/me/claims` (mục 0). Còn chờ: mã đơn trên sàn và sàn (L3) | ✅ |
| Voucher | Đã nối `GET /api/v1/loyalty/me/vouchers` (mục 0). Còn chờ: sàn và hạn dùng (L4) | ✅ |
| Claim đơn | BE có `POST /api/v1/loyalty/claims` `{ orderId, totalAmount }` nhưng đòi id nội bộ (L2). Đề xuất `{ platform, orderCode }`; lỗi trả `code` rõ lý do (chưa hoàn tất / chưa đủ 15 ngày / đã claim / không tìm thấy) | 🟡 |
| Chatbot | `POST /api/storefront/chat` | ⚪ |
| Đăng ký khách (A-05) | Đã có `POST /api/v1/auth/register` (mục 1). Còn chờ: gắn khách vào cửa hàng theo `subdomain`; OTP xác minh email nếu cần | ✅ (không OTP) |
| Cửa hàng của khách (C-00) | `GET /api/customer/shops` → `[{ tenantId, name, logoUrl, tier, points }]`; `GET /api/storefront/shops/{shopCode}` (xem trước); `POST /api/customer/shops` `{ shopCode }` (tham gia) | ⚪ (mock) |

**Nhiều cửa hàng:** BE lấy tenant từ JWT (`/api/v1/loyalty/*` đọc `TenantContext`), Nginx xóa header `X-Tenant-Id`, nên app không gửi header này. JWT của khách mang một `tenantId` cố định (cửa hàng lúc đăng ký), vì vậy chưa xem được cửa hàng khác (L6).

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
| M-10 Cảnh báo AI | `GET /api/v1/ai/alerts` → `[{ skuId, skuCode, productName, type, message }]` | `dashboardSummaryProvider` (`dashboard_data.dart`) |
| M-21 Chi tiết đơn | Đã nối `GET /api/v1/orders/{id}` (mục 2). Còn đề xuất: điền `skuCode`, `productName` và thêm `variantName` cho `items` | `OrdersMockRepository` (chỉ chế độ mock) |
| M-22 In vận đơn | `GET /api/v1/orders/{id}/shipping-label` → `application/pdf`; `409` + `errorCode: LABEL_NOT_READY` khi sàn chưa tạo tem | `ShippingLabelMockRepository` (tem mẫu PDF) |
| M-30 Sản phẩm | Đã nối `GET /api/v1/products` và `/products/skus` (mục 2). Còn đề xuất: tìm theo `keyword` và link sàn | `ProductsMockRepository` (chỉ chế độ mock) |
| M-40 Tồn kho | Đã nối `GET /api/v1/inventory` (mục 2). Còn đề xuất: lọc `?lowStock=true`, trả kèm `variantName` | `InventoryMockRepository` (chỉ chế độ mock) |
| M-60 Hộp thư CSKH | `GET /api/conversations?filter=ALL\|COMPLAINT\|UNREPLIED&platform=` | `InboxMockRepository.listConversations` |
| M-61 Hội thoại | `GET /api/conversations/{id}`, `GET /api/conversations/{id}/messages`, `POST /api/conversations/{id}/messages` `{ text }` → tin có `deliveryStatus` (`SENDING` / `SENT` / `UNKNOWN`), `POST /api/conversations/{id}/read`, `POST /api/conversations/{id}/resolve`, `PUT /api/conversations/{id}/order` `{ orderId }` | `InboxMockRepository` (chờ Message Service) |

### 4.3. Chỉ Tenant Admin

| Màn hình | Endpoint đề xuất | Mock đang thay thế |
|---|---|---|
| T-10 Kết nối sàn | Đã nối OAuth, ngắt kết nối, tự nhập Shopee (mục 2). Còn chờ: API bật/tắt tự nhập cho TikTok | `MarketplaceMockRepository` (chỉ chế độ mock, OAuth giả không mở trình duyệt) |
| T-20 Nhân viên | Đã nối `/api/v1/users` (mục 2). Còn đề xuất: BE chặn chủ cửa hàng tự khóa mình | `StaffMockRepository` (chỉ chế độ mock) |
| T-30 Phát voucher | `GET /api/customers?fields=id,name,email,tier` (khách của cửa hàng); `GET /api/vouchers/capabilities` → `{ SHOPEE: AVAILABLE\|UNSUPPORTED\|NOT_CONNECTED, … }`; `GET /api/voucher-batches`; `POST /api/voucher-batches` `{ platform, discount, minOrder, expiresAt, customerIds }` → đợt `CREATING`, sau đó `SUCCESS` / `FAILED` (+ `failureReason`) / `UNKNOWN`. Chỉ gửi email khi sàn xác nhận tạo thành công; đợt `UNKNOWN` cần đối soát, không tạo lại | `VoucherMockRepository` |
| T-40 Gói dịch vụ | Đã nối trạng thái gói, hóa đơn, thanh toán (mục 0). Còn đề xuất (P3): `GET /api/v1/tenants/subscription/usage` → `{ skus, connections, imageStorageGb }` (mỗi mục `{ used, limit }`, `limit: null` = không giới hạn); API đổi / hạ gói | `SubscriptionMockRepository.usage` (luôn mock) |
| T-50 Hỗ trợ | `GET /api/support-tickets` → `[{ id, code, title, status: OPEN\|IN_PROGRESS\|RESOLVED, updatedAt, lastReply: { author: SUPPORT\|ME, text }? }]`; `POST /api/support-tickets` `{ title (≤ 120), description (≤ 2.000) }` | `SupportMockRepository` |

### 4.4. Customer

BE lấy tenant từ JWT, app không gửi `X-Tenant-Id` (xem L6 ở mục 0).

| Màn hình | Endpoint đề xuất | Mock đang thay thế |
|---|---|---|
| C-00 Cửa hàng của bạn | `GET /api/customer/shops` → `[{ tenantId, name, logoUrl, tier, points }]`; `GET /api/storefront/shops/{shopCode}` (xem trước); `POST /api/customer/shops` `{ shopCode }` (tham gia) | `CustomerShopMockRepository` |
| C-10 Sản phẩm | `GET /api/storefront/products` (chỉ sản phẩm ACTIVE + URL sàn) | `StorefrontMockRepository.listProducts` |
| C-11 Chi tiết sản phẩm | `GET /api/storefront/products/{id}` | `StorefrontMockRepository.getProduct` |
| C-12 Trợ lý | `POST /api/storefront/chat` `{ question }` → `{ text, productIds: [], fallback }` (không đặt hàng) | `ChatbotMockRepository` |
| C-20 Điểm & hạng | Đã nối `/api/v1/loyalty/me`, `/me/claims`, `/me/vouchers` (`LoyaltyRemoteRepository`). Còn đề xuất: L3, L4 | `LoyaltyMockRepository.getSummary`, `.getVouchers` (chỉ chế độ mock) |
| C-30 Claim đơn | BE có `POST /api/v1/loyalty/claims` nhưng đòi `orderId` nội bộ (L2). Đề xuất `{ platform, orderCode }` → `{ points, newTier? }`; lỗi có `errorCode` (`NOT_COMPLETED`, `WAITING_PERIOD` + ngày được claim, `ALREADY_CLAIMED`, `NOT_FOUND`, `TOO_MANY_ATTEMPTS` + thời gian chờ) | `LoyaltyMockRepository.claimOrder` |

### 4.5. Yêu cầu chung

1. ~~Thêm role `CUSTOMER` vào login~~: đã có ở BE `develop` (`/api/v1/auth/login`).
2. **Trả DTO thay vì entity** (README backend đã nêu nguyên tắc này) để tránh lộ trường như `appSecretEncrypted`.
3. Giữ định dạng lỗi `{ success: false, message }` cho mọi lỗi (kể cả 401/403 từ Spring Security) để app hiển thị đúng.
4. Cấu hình CORS không cần cho mobile, nhưng cần cho web portal sau này.
5. **Trả kèm `errorCode`** trong body lỗi (`{ success: false, message, errorCode }`). `BusinessException` đã có mã (`INVALID_CREDENTIALS`, `ACCOUNT_TEMP_LOCKED`, `ACCOUNT_DISABLED`) nhưng `GlobalExceptionHandler` chưa gửi ra, nên màn A-02 đang phải đoán loại lỗi qua nội dung `message` (xem `lib/features/auth/domain/auth_failure.dart`).
6. **Khóa tenant khi đăng nhập (FR-003):** app chờ `403` với `errorCode: TENANT_LOCKED` (mock đang giả lập đúng như vậy).
7. **Khách dùng nhiều cửa hàng:** tách tài khoản khách khỏi tenant (bảng nối khách–cửa hàng), thêm các API ở mục 3 (đăng ký + OTP, danh sách/tham gia cửa hàng) và cách chọn cửa hàng cho API khách (BE hiện lấy tenant từ JWT, xem L6).
8. **Dự báo M-51, "Nên nhập thêm":** API dự báo trả `recommendedReorderQty` theo từng ngày. App đang hiển thị **giá trị lớn nhất trong 7 ngày** (`summarizeForecast` ở `lib/features/ai_insights/domain/demand_forecast.dart`). Cần backend xác nhận: đó là số nên nhập cho cả 7 ngày, hay phải cộng dồn, hay nên trả sẵn một con số tổng.
