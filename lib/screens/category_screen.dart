import 'package:flutter/material.dart';
import 'package:videoapp/models/video_model.dart';
import 'season_list_page.dart';

class CategoryScreen extends StatefulWidget {
  final List<Series> allSeries;
  final Map<String, String> categoryImages;

  const CategoryScreen({
    required this.allSeries,
    required this.categoryImages,
    super.key,
  });

  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String searchQuery = "";
  bool isGridView = true;

  @override
  Widget build(BuildContext context) {
    // Serilerdeki kategorilerden benzersiz bir liste oluştur
    final allCategories =
        widget.allSeries.expand((series) => series.categories).toSet().toList();

    // Arama sorgusuna göre kategorileri filtrele
    final filteredCategories = allCategories
        .where((category) =>
            category.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Kategoriler",
            style: TextStyle(color: Colors.white, fontSize: 22)),
        actions: [
          IconButton(
            icon: Icon(isGridView ? Icons.list : Icons.grid_view,
                color: Colors.white),
            onPressed: () {
              setState(() {
                isGridView = !isGridView;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        child: Column(
          children: [
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[800],
                hintText: "Kategori ara...",
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (query) {
                setState(() {
                  searchQuery = query;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isGridView
                  ? GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.0,
                      ),
                      itemCount: filteredCategories.length,
                      itemBuilder: (context, index) {
                        return _buildCategoryCard(filteredCategories[index]);
                      },
                    )
                  : ListView.builder(
                      itemCount: filteredCategories.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0), // Kategoriler arasındaki boşluk
                          child: _buildCategoryCard(filteredCategories[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String category) {
    return GestureDetector(
      onTap: () {
        final filteredSeries = widget.allSeries
            .where((series) => series.categories.contains(category))
            .toList();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FilteredSeriesScreen(
                category: category, filteredSeries: filteredSeries),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(0, 3),
              blurRadius: 6,
            ),
          ],
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.5),
              Colors.blueAccent.withOpacity(0.9)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          image: widget.categoryImages.containsKey(category)
              ? DecorationImage(
                  image: NetworkImage(widget.categoryImages[category]!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.5), BlendMode.darken),
                )
              : null,
        ),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: Text(
          category,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class FilteredSeriesScreen extends StatelessWidget {
  final String category;
  final List<Series> filteredSeries;

  const FilteredSeriesScreen({
    required this.category,
    required this.filteredSeries,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Kategori: $category",
            style: const TextStyle(color: Colors.white)),
      ),
      body: filteredSeries.isEmpty
          ? const Center(
              child: Text("Bu kategoriye ait seri bulunamadı.",
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            )
          : Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ListView.builder(
                itemCount: filteredSeries.length,
                itemBuilder: (context, index) {
                  final series = filteredSeries[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        series.cover,
                        width: 100,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(series.title,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18)),
                    subtitle: Text(series.description,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.arrow_forward,
                        color: Colors.orangeAccent),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SeasonListPage(series)),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}
