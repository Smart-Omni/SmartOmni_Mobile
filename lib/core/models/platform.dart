/// Sàn thương mại điện tử. Khớp enum `platform_type` của backend.
enum Platform {
  shopee('SHOPEE', 'Shopee'),
  tiktokShop('TIKTOK_SHOP', 'TikTok Shop');

  const Platform(this.backendValue, this.label);

  final String backendValue;
  final String label;

  static Platform fromBackend(String? value) => Platform.values.firstWhere(
    (p) => p.backendValue == value?.toUpperCase(),
    orElse: () => Platform.shopee,
  );
}
