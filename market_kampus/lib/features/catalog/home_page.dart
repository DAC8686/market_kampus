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
    double screenWidth = MediaQuery.of(context).size.width;
    double scaleW = screenWidth / 412;

    return Scaffold(
      backgroundColor: MpusTheme.backgroundColor,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: MpusTheme.primaryColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20 * scaleW),
            topRight: Radius.circular(20 * scaleW),
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
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20 * scaleW),
            topRight: Radius.circular(20 * scaleW),
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
            iconSize: 30 * scaleW,
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
            Positioned(
              left: 165 * scaleW,
              top: 366 * scaleW,
              child: SvgPicture.asset(
                'assets/Mpus1.svg',
                width: 83 * scaleW,
                height: 30 * scaleW,
                colorFilter: const ColorFilter.mode(
                  MpusTheme.textSecondaryColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
            _selectedIndex == 0
                ? _buildHomeContent(scaleW)
                : const ProfilePage(),
          ],
        ),
      ),
    );
  }

  // --- KONTEN HALAMAN HOME ---
  Widget _buildHomeContent(double scaleW) {
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
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20 * scaleW),
              bottomRight: Radius.circular(20 * scaleW),
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
                top: 10 * scaleW,
                child: Opacity(
                  opacity: 0.6,
                  child: SvgPicture.asset(
                    'assets/Logo1.svg',
                    width: 98 * scaleW,
                    height: 85 * scaleW,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              Column(
                children: [
                  SizedBox(height: 25 * scaleW),

                  // BAR PENCARIAN
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 80 * scaleW),
                    child: Container(
                      height: 29 * scaleW,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25 * scaleW),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Sepatu, tas, jasa, dll',
                          hintStyle: TextStyle(
                            color: MpusTheme.textSecondaryColor,
                            fontSize: 14 * scaleW,
                            fontFamily: "Roboto",
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: MpusTheme.textSecondaryColor,
                            size: 22 * scaleW,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 50 * scaleW),

                  // FILTER ROW
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 5 * scaleW),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFilterItem("Terkait", scaleW),
                        _buildDivider(scaleW),
                        _buildFilterItem("Terbaru", scaleW),
                        _buildDivider(scaleW),
                        _buildFilterItem("Termurah", scaleW),
                        _buildDivider(scaleW),
                        _buildFilterItem("Termahal", scaleW),
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
                    style: TextStyle(color: Colors.grey),
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
                return const Center(child: Text("Barang tidak ditemukan."));
              }

              return GridView.builder(
                padding: EdgeInsets.only(
                  top: 15 * scaleW,
                  left: 15 * scaleW,
                  right: 15 * scaleW,
                  bottom: 20 * scaleW,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15 * scaleW,
                  mainAxisSpacing: 15 * scaleW,
                  childAspectRatio: 0.85,
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
                        borderRadius: BorderRadius.circular(15 * scaleW),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── 1. GAMBAR BARANG ──
                          Container(
                            height: 130 * scaleW,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E5E5),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(15 * scaleW),
                              ),
                              image: firstImage != null
                                  ? DecorationImage(
                                      image: NetworkImage(firstImage),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: firstImage == null
                                ? Icon(Icons.image, size: 50 * scaleW, color: Colors.grey)
                                : null,
                          ),

                          // ── 2. TEKS BARANG ──
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(10 * scaleW),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item['name'] ?? 'Tanpa Nama',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.roboto(
                                      fontSize: 14 * scaleW,
                                      color: const Color(0xFF4A4A4A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatCurrency(item['price']),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14 * scaleW,
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

  Widget _buildFilterItem(String title, double scaleW) {
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
          fontSize: 13 * scaleW,
          fontFamily: "Roboto",
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF8F8F8F) : MpusTheme.textSecondaryColor,
        ),
      ),
    );
  }

  Widget _buildDivider(double scaleW) {
    return Container(
      height: 15 * scaleW,
      width: 2 * scaleW,
      color: MpusTheme.textSecondaryColor,
    );
  }
}
