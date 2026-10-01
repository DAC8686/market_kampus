import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/mpus_theme.dart';
import '../profile/profile_page.dart';
import 'product_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _selectedFilter = 'Terbaru';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  int _parsePrice(dynamic priceData) {
    if (priceData == null) return 0;
    String priceStr = priceData.toString();
    String numericOnly = priceStr.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericOnly.isEmpty) return 0;
    return int.parse(numericOnly);
  }

  String _formatCurrency(dynamic price) {
    int amount = _parsePrice(price);
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpusTheme.backgroundColor,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: MpusTheme.primaryColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: const Color(0xFF8F8F8F),
            unselectedItemColor: MpusTheme.textSecondaryColor,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            iconSize: 28,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Opacity(
                opacity: 0.08,
                child: SvgPicture.asset(
                  'assets/Mpus1.svg',
                  width: 140,
                  height: 50,
                  colorFilter: const ColorFilter.mode(
                    MpusTheme.textSecondaryColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            _selectedIndex == 0
                ? _buildHomeContent()
                : const ProfilePage(),
          ],
        ),
      ),
    );
  }

  // --- KONTEN HALAMAN HOME ---
  Widget _buildHomeContent() {
    return Column(
      children: [
        // LAYER ATAS: HEADER DENGAN LOGO BACKGROUND & FILTER
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                MpusTheme.primaryColor,
                MpusTheme.primaryColor.withValues(alpha: 0.8),
                Colors.white.withValues(alpha: 0.6),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // WATERMARK LOGO
              Positioned(
                top: 10,
                child: Opacity(
                  opacity: 0.5,
                  child: SvgPicture.asset(
                    'assets/Logo1.svg',
                    width: 90,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              Column(
                children: [
                  const SizedBox(height: 20),

                  // BAR PENCARIAN
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.toLowerCase();
                            });
                          },
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: MpusTheme.textDarkColor,
                            fontFamily: "Roboto",
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            hintText: 'Cari sepatu, tas, buku, jasa, dll...',
                            hintStyle: TextStyle(
                              color: MpusTheme.textSecondaryColor,
                              fontSize: 13.5,
                              fontFamily: "Roboto",
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: MpusTheme.textSecondaryColor,
                              size: 20,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // FILTER ROW
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFilterItem("Terkait"),
                        _buildDivider(),
                        _buildFilterItem("Terbaru"),
                        _buildDivider(),
                        _buildFilterItem("Termurah"),
                        _buildDivider(),
                        _buildFilterItem("Termahal"),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // LAYER BAWAH: GRID BARANG SUPABASE REALTIME
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseConfig.client
                .from('products')
                .stream(primaryKey: ['id'])
                .eq('is_sold', false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    "Belum ada barang di kampus ini.\nJadilah yang pertama berjualan!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                );
              }

              List<Map<String, dynamic>> products = List.from(snapshot.data!);

              // 1. FUNGSI PENCARIAN (Search)
              if (_searchQuery.isNotEmpty) {
                products = products.where((item) {
                  String name = (item['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();
              }

              // 2. FUNGSI PENGURUTAN (Filter)
              products.sort((a, b) {
                if (_selectedFilter == 'Termurah' || _selectedFilter == 'Termahal') {
                  int priceA = _parsePrice(a['price']);
                  int priceB = _parsePrice(b['price']);
                  
                  if (_selectedFilter == 'Termurah') {
                    return priceA.compareTo(priceB);
                  } else {
                    return priceB.compareTo(priceA);
                  }
                } else {
                  // Default ke 'Terbaru'
                  DateTime timeA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
                  DateTime timeB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
                  return timeB.compareTo(timeA);
                }
              });

              if (products.isEmpty) {
                return const Center(
                  child: Text(
                    "Barang tidak ditemukan.",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.74,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  var item = products[index];
                  
                  List imagesList = item['images'] is List ? item['images'] : [];
                  String? firstImage = imagesList.isNotEmpty ? imagesList[0] : null;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailPage(
                            productData: item,
                            productId: item['id'].toString(),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.05),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── 1. GAMBAR BARANG ──
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(14),
                            ),
                            child: AspectRatio(
                              aspectRatio: 1.15,
                              child: Container(
                                color: const Color(0xFFF0F4F4),
                                child: firstImage != null
                                    ? Image.network(
                                        firstImage,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => const Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Colors.grey,
                                          size: 40,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.image_outlined,
                                        size: 44,
                                        color: Colors.grey,
                                      ),
                              ),
                            ),
                          ),

                          // ── 2. TEKS BARANG ──
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? 'Tanpa Nama',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.roboto(
                                      fontSize: 13.5,
                                      color: const Color(0xFF333333),
                                      fontWeight: FontWeight.w500,
                                      height: 1.2,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatCurrency(item['price']),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: MpusTheme.tealDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterItem(String title) {
    bool isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = title;
        });
      },
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontFamily: "Roboto",
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF555555) : MpusTheme.textSecondaryColor,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 14,
      width: 1.5,
      color: MpusTheme.textSecondaryColor.withValues(alpha: 0.6),
    );
  }
}
