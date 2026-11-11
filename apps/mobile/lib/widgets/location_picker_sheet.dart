import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class CambodiaLocationItem {
  final String provinceKh;
  final String provinceEn;
  final String? districtKh;
  final String? districtEn;
  final double lat;
  final double lng;
  final String type; // 'province', 'district', 'landmark'

  const CambodiaLocationItem({
    required this.provinceKh,
    required this.provinceEn,
    this.districtKh,
    this.districtEn,
    required this.lat,
    required this.lng,
    this.type = 'province',
  });

  String get displayNameKh {
    if (districtKh != null && districtKh!.isNotEmpty) {
      return '$districtKh, $provinceKh';
    }
    return provinceKh;
  }

  String get displayNameEn {
    if (districtEn != null && districtEn!.isNotEmpty) {
      return '$districtEn, $provinceEn';
    }
    return provinceEn;
  }
}

class LocationPickerSheet extends StatefulWidget {
  final String? initialLocation;

  const LocationPickerSheet({super.key, this.initialLocation});

  static Future<String?> show(BuildContext context, {String? initialLocation}) {
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => LocationPickerSheet(initialLocation: initialLocation),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _activeSegment = 0; // 0: List, 1: Interactive Map
  bool _isLocating = false;
  String? _gpsStatus;
  late List<CambodiaLocationItem> _filteredLocations;
  static bool _mapViewRegistered = false;
  static final String _mapViewType = 'osm-cambodia-map-${DateTime.now().millisecondsSinceEpoch}';

  // Comprehensive Cambodia Database: 25 Provinces, Major Districts & Famous Landmarks
  static const List<CambodiaLocationItem> allCambodiaLocations = [
    // 1. Phnom Penh (Capital)
    CambodiaLocationItem(provinceKh: 'រាជធានីភ្នំពេញ', provinceEn: 'Phnom Penh', lat: 11.5564, lng: 104.9282, type: 'province'),
    CambodiaLocationItem(provinceKh: 'រាជធានីភ្នំពេញ', provinceEn: 'Phnom Penh', districtKh: 'ខណ្ឌដូនពេញ (Daun Penh)', districtEn: 'Daun Penh', lat: 11.5721, lng: 104.9255, type: 'district'),
    CambodiaLocationItem(provinceKh: 'រាជធានីភ្នំពេញ', provinceEn: 'Phnom Penh', districtKh: 'ខណ្ឌបឹងកេងកង (Boeung Keng Kang)', districtEn: 'BKK1', lat: 11.5528, lng: 104.9248, type: 'district'),
    CambodiaLocationItem(provinceKh: 'រាជធានីភ្នំពេញ', provinceEn: 'Phnom Penh', districtKh: 'ខណ្ឌទួលទំពូង / ចំការមន (Chamkar Mon)', districtEn: 'Toul Tompoung', lat: 11.5401, lng: 104.9152, type: 'district'),
    CambodiaLocationItem(provinceKh: 'រាជធានីភ្នំពេញ', provinceEn: 'Phnom Penh', districtKh: 'ខណ្ឌទួលគោក (Toul Kork)', districtEn: 'Toul Kork', lat: 11.5739, lng: 104.8992, type: 'district'),
    CambodiaLocationItem(provinceKh: 'រាជធានីភ្នំពេញ', provinceEn: 'Phnom Penh', districtKh: 'ខណ្ឌសែនសុខ (Sen Sok)', districtEn: 'Sen Sok', lat: 11.5892, lng: 104.8722, type: 'district'),
    CambodiaLocationItem(provinceKh: 'រាជធានីភ្នំពេញ', provinceEn: 'Phnom Penh', districtKh: 'ខណ្ឌជ្រោយចង្វារ (Chroy Changvar)', districtEn: 'Chroy Changvar', lat: 11.6021, lng: 104.9351, type: 'district'),
    CambodiaLocationItem(provinceKh: 'រាជធានីភ្នំពេញ', provinceEn: 'Phnom Penh', districtKh: 'ខណ្ឌ៧មករា (7 Makara)', districtEn: '7 Makara', lat: 11.5645, lng: 104.9124, type: 'district'),
    CambodiaLocationItem(provinceKh: 'រាជធានីភ្នំពេញ', provinceEn: 'Phnom Penh', districtKh: 'ខណ្ឌមានជ័យ (Mean Chey)', districtEn: 'Mean Chey', lat: 11.5284, lng: 104.9238, type: 'district'),
    CambodiaLocationItem(provinceKh: 'រាជធានីភ្នំពេញ', provinceEn: 'Phnom Penh', districtKh: 'ខណ្ឌច្បារអំពៅ (Chbar Ampov)', districtEn: 'Chbar Ampov', lat: 11.5305, lng: 104.9547, type: 'district'),
    CambodiaLocationItem(provinceKh: 'រាជធានីភ្នំពេញ', provinceEn: 'Phnom Penh', districtKh: 'វិមានឯករាជ្យ & មាត់ទន្លេ (Independence Monument)', districtEn: 'Riverside', lat: 11.5562, lng: 104.9282, type: 'landmark'),

    // 2. Siem Reap
    CambodiaLocationItem(provinceKh: 'ខេត្តសៀមរាប', provinceEn: 'Siem Reap', lat: 13.3671, lng: 103.8448, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តសៀមរាប', provinceEn: 'Siem Reap', districtKh: 'ក្រុងសៀមរាប (Siem Reap Town)', districtEn: 'Siem Reap Town', lat: 13.3633, lng: 103.8564, type: 'district'),
    CambodiaLocationItem(provinceKh: 'ខេត្តសៀមរាប', provinceEn: 'Siem Reap', districtKh: 'ប្រាសាទអង្គរវត្ត (Angkor Wat)', districtEn: 'Angkor Wat', lat: 13.4125, lng: 103.8670, type: 'landmark'),
    CambodiaLocationItem(provinceKh: 'ខេត្តសៀមរាប', provinceEn: 'Siem Reap', districtKh: 'ស្រុកបន្ទាយស្រី (Banteay Srei)', districtEn: 'Banteay Srei', lat: 13.5989, lng: 103.9630, type: 'district'),
    CambodiaLocationItem(provinceKh: 'ខេត្តសៀមរាប', provinceEn: 'Siem Reap', districtKh: 'ផាប់ស្ទ្រីត & ផ្សារចាស់ (Pub Street)', districtEn: 'Pub Street', lat: 13.3547, lng: 103.8549, type: 'landmark'),

    // 3. Battambang
    CambodiaLocationItem(provinceKh: 'ខេត្តបាត់ដំបង', provinceEn: 'Battambang', lat: 13.0957, lng: 103.2022, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តបាត់ដំបង', provinceEn: 'Battambang', districtKh: 'ក្រុងបាត់ដំបង (Battambang City)', districtEn: 'Battambang City', lat: 13.1027, lng: 103.1982, type: 'district'),
    CambodiaLocationItem(provinceKh: 'ខេត្តបាត់ដំបង', provinceEn: 'Battambang', districtKh: 'ស្រុកបាណន់ & ភ្នំសំពៅ (Phnom Sampov)', districtEn: 'Banan', lat: 13.0234, lng: 103.1256, type: 'landmark'),

    // 4. Preah Sihanouk (Kompong Som)
    CambodiaLocationItem(provinceKh: 'ខេត្តព្រះសីហនុ', provinceEn: 'Preah Sihanouk', lat: 10.6253, lng: 103.5234, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តព្រះសីហនុ', provinceEn: 'Preah Sihanouk', districtKh: 'ក្រុងព្រះសីហនុ (Sihanoukville)', districtEn: 'Sihanoukville', lat: 10.6274, lng: 103.5221, type: 'district'),
    CambodiaLocationItem(provinceKh: 'ខេត្តព្រះសីហនុ', provinceEn: 'Preah Sihanouk', districtKh: 'ក្រុងកោះរ៉ុង (Koh Rong Island)', districtEn: 'Koh Rong', lat: 10.7242, lng: 103.2384, type: 'landmark'),
    CambodiaLocationItem(provinceKh: 'ខេត្តព្រះសីហនុ', provinceEn: 'Preah Sihanouk', districtKh: 'ឆ្នេរអូរឈើទាល & អូរត្រេះ (Otres Beach)', districtEn: 'Otres Beach', lat: 10.5843, lng: 103.5492, type: 'landmark'),

    // 5. Kampot
    CambodiaLocationItem(provinceKh: 'ខេត្តកំពត', provinceEn: 'Kampot', lat: 10.6104, lng: 104.1815, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តកំពត', provinceEn: 'Kampot', districtKh: 'ក្រុងកំពត (Kampot Town)', districtEn: 'Kampot Town', lat: 10.5942, lng: 104.1640, type: 'district'),
    CambodiaLocationItem(provinceKh: 'ខេត្តកំពត', provinceEn: 'Kampot', districtKh: 'ឧទ្យានជាតិព្រះមុនីវង្សបូកគោ (Bokor Mountain)', districtEn: 'Bokor Mountain', lat: 10.6272, lng: 104.0321, type: 'landmark'),
    CambodiaLocationItem(provinceKh: 'ខេត្តកំពត', provinceEn: 'Kampot', districtKh: 'ស្រុកទឹកឈូ & ស្ទឹងកំពត (Tuek Chhou)', districtEn: 'Tuek Chhou', lat: 10.6512, lng: 104.1482, type: 'district'),

    // 6. Kandal
    CambodiaLocationItem(provinceKh: 'ខេត្តកណ្តាល', provinceEn: 'Kandal', lat: 11.4552, lng: 104.9514, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តកណ្តាល', provinceEn: 'Kandal', districtKh: 'ក្រុងតាខ្មៅ (Ta Khmau City)', districtEn: 'Ta Khmau', lat: 11.4833, lng: 104.9500, type: 'district'),
    CambodiaLocationItem(provinceKh: 'ខេត្តកណ្តាល', provinceEn: 'Kandal', districtKh: 'ស្រុកកៀនស្វាយ (Kien Svay)', districtEn: 'Kien Svay', lat: 11.5012, lng: 105.0482, type: 'district'),

    // 7. Kampong Cham
    CambodiaLocationItem(provinceKh: 'ខេត្តកំពង់ចាម', provinceEn: 'Kampong Cham', lat: 11.9924, lng: 105.4645, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តកំពង់ចាម', provinceEn: 'Kampong Cham', districtKh: 'ក្រុងកំពង់ចាម (Kampong Cham City)', districtEn: 'Kampong Cham City', lat: 11.9934, lng: 105.4635, type: 'district'),

    // 8. Kampong Thom
    CambodiaLocationItem(provinceKh: 'ខេត្តកំពង់ធំ', provinceEn: 'Kampong Thom', lat: 12.7111, lng: 104.8887, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តកំពង់ធំ', provinceEn: 'Kampong Thom', districtKh: 'ប្រាសាទសំបូរព្រៃគុក (Sambor Prei Kuk)', districtEn: 'Sambor Prei Kuk', lat: 12.8681, lng: 105.0411, type: 'landmark'),

    // 9. Kampong Chhnang
    CambodiaLocationItem(provinceKh: 'ខេត្តកំពង់ឆ្នាំង', provinceEn: 'Kampong Chhnang', lat: 12.2500, lng: 104.6667, type: 'province'),

    // 10. Kampong Speu
    CambodiaLocationItem(provinceKh: 'ខេត្តកំពង់ស្ពឺ', provinceEn: 'Kampong Speu', lat: 11.4531, lng: 104.5209, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តកំពង់ស្ពឺ', provinceEn: 'Kampong Speu', districtKh: 'ឧទ្យានជាតិគិរីរម្យ (Kirirom National Park)', districtEn: 'Kirirom', lat: 11.3167, lng: 104.0667, type: 'landmark'),

    // 11. Kep
    CambodiaLocationItem(provinceKh: 'ខេត្តកែប', provinceEn: 'Kep', lat: 10.4828, lng: 104.2986, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តកែប', provinceEn: 'Kep', districtKh: 'ផ្សារក្តាម & ឆ្នេរកែប (Crab Market & Beach)', districtEn: 'Kep Crab Market', lat: 10.4902, lng: 104.2941, type: 'landmark'),

    // 12. Koh Kong
    CambodiaLocationItem(provinceKh: 'ខេត្តកោះកុង', provinceEn: 'Koh Kong', lat: 11.6153, lng: 102.9838, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តកោះកុង', provinceEn: 'Koh Kong', districtKh: 'រមណីយដ្ឋានតាតៃ (Tatai River)', districtEn: 'Tatai', lat: 11.5833, lng: 103.1167, type: 'landmark'),

    // 13. Kratie
    CambodiaLocationItem(provinceKh: 'ខេត្តក្រចេះ', provinceEn: 'Kratie', lat: 12.4881, lng: 106.0188, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តក្រចេះ', provinceEn: 'Kratie', districtKh: 'ព្រែកកាំពី មើលផ្សោតទឹកសាប (Kampi Dolphin)', districtEn: 'Kampi Dolphin', lat: 12.5932, lng: 105.9984, type: 'landmark'),

    // 14. Mondulkiri
    CambodiaLocationItem(provinceKh: 'ខេត្តមណ្ឌលគិរី', provinceEn: 'Mondulkiri', lat: 12.4558, lng: 107.1881, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តមណ្ឌលគិរី', provinceEn: 'Mondulkiri', districtKh: 'ក្រុងសែនមនោរម្យ (Senmonorom)', districtEn: 'Senmonorom', lat: 12.4578, lng: 107.1895, type: 'district'),
    CambodiaLocationItem(provinceKh: 'ខេត្តមណ្ឌលគិរី', provinceEn: 'Mondulkiri', districtKh: 'ទឹកធ្លាក់ប៊ូស្រា (Bou Sra Waterfall)', districtEn: 'Bou Sra', lat: 12.5694, lng: 107.4194, type: 'landmark'),

    // 15. Ratanakiri
    CambodiaLocationItem(provinceKh: 'ខេត្តរតនគិរី', provinceEn: 'Ratanakiri', lat: 13.7394, lng: 106.9873, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តរតនគិរី', provinceEn: 'Ratanakiri', districtKh: 'បឹងយក្សឡោម (Yeak Laom Lake)', districtEn: 'Yeak Laom Lake', lat: 13.7317, lng: 107.0175, type: 'landmark'),

    // 16. Preah Vihear
    CambodiaLocationItem(provinceKh: 'ខេត្តព្រះវិហារ', provinceEn: 'Preah Vihear', lat: 13.8073, lng: 104.9811, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តព្រះវិហារ', provinceEn: 'Preah Vihear', districtKh: 'ប្រាសាទព្រះវិហារ (Preah Vihear Temple)', districtEn: 'Preah Vihear Temple', lat: 14.3917, lng: 104.6800, type: 'landmark'),

    // 17. Stung Treng
    CambodiaLocationItem(provinceKh: 'ខេត្តស្ទឹងត្រែង', provinceEn: 'Stung Treng', lat: 13.5259, lng: 105.9683, type: 'province'),

    // 18. Svay Rieng
    CambodiaLocationItem(provinceKh: 'ខេត្តស្វាយរៀង', provinceEn: 'Svay Rieng', lat: 11.0879, lng: 105.7994, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តស្វាយរៀង', provinceEn: 'Svay Rieng', districtKh: 'ក្រុងបាវិត (Bavet Border)', districtEn: 'Bavet', lat: 11.0772, lng: 106.1458, type: 'district'),

    // 19. Prey Veng
    CambodiaLocationItem(provinceKh: 'ខេត្តព្រៃវែង', provinceEn: 'Prey Veng', lat: 11.4851, lng: 105.3253, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តព្រៃវែង', provinceEn: 'Prey Veng', districtKh: 'ស្ពានត្សឹបាសា (Neak Loeung Bridge)', districtEn: 'Neak Loeung', lat: 11.2583, lng: 105.2806, type: 'landmark'),

    // 20. Takeo
    CambodiaLocationItem(provinceKh: 'ខេត្តតាកែវ', provinceEn: 'Takeo', lat: 10.9908, lng: 104.7847, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តតាកែវ', provinceEn: 'Takeo', districtKh: 'ប្រាសាទភ្នំជីសូរ (Phnom Chisor)', districtEn: 'Phnom Chisor', lat: 11.0347, lng: 104.8589, type: 'landmark'),

    // 21. Pursat
    CambodiaLocationItem(provinceKh: 'ខេត្តពោធិ៍សាត់', provinceEn: 'Pursat', lat: 12.5388, lng: 103.9192, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តពោធិ៍សាត់', provinceEn: 'Pursat', districtKh: 'ភ្នំ១៥០០ & ស្រុកវាលវែង (Veal Veng / Phnom 1500)', districtEn: 'Phnom 1500', lat: 12.1833, lng: 103.2167, type: 'landmark'),

    // 22. Pailin
    CambodiaLocationItem(provinceKh: 'ខេត្តប៉ៃលិន', provinceEn: 'Pailin', lat: 12.8489, lng: 102.6093, type: 'province'),

    // 23. Banteay Meanchey
    CambodiaLocationItem(provinceKh: 'ខេត្តបន្ទាយមានជ័យ', provinceEn: 'Banteay Meanchey', lat: 13.5859, lng: 102.9737, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តបន្ទាយមានជ័យ', provinceEn: 'Banteay Meanchey', districtKh: 'ក្រុងប៉ោយប៉ែត (Poipet City)', districtEn: 'Poipet', lat: 13.6558, lng: 102.5636, type: 'district'),

    // 24. Oddar Meanchey
    CambodiaLocationItem(provinceKh: 'ខេត្តឧត្តរមានជ័យ', provinceEn: 'Oddar Meanchey', lat: 14.1818, lng: 103.5176, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តឧត្តរមានជ័យ', provinceEn: 'Oddar Meanchey', districtKh: 'ស្រុកអន្លង់វែង (Anlong Veng)', districtEn: 'Anlong Veng', lat: 14.3417, lng: 104.1000, type: 'district'),

    // 25. Tboung Khmum
    CambodiaLocationItem(provinceKh: 'ខេត្តត្បូងឃ្មុំ', provinceEn: 'Tboung Khmum', lat: 11.9056, lng: 105.8672, type: 'province'),
    CambodiaLocationItem(provinceKh: 'ខេត្តត្បូងឃ្មុំ', provinceEn: 'Tboung Khmum', districtKh: 'ក្រុងសួង (Suong City)', districtEn: 'Suong City', lat: 11.9056, lng: 105.6567, type: 'district'),
  ];

  @override
  void initState() {
    super.initState();
    _filteredLocations = List.from(allCambodiaLocations);
    _registerWebMap();
  }

  void _registerWebMap() {
    if (kIsWeb && !_mapViewRegistered) {
      _mapViewRegistered = true;
      ui_web.platformViewRegistry.registerViewFactory(_mapViewType, (int viewId) {
        final iframe = html.IFrameElement()
          ..src = 'https://www.openstreetmap.org/export/embed.html?bbox=102.3,9.9,107.6,14.7&layer=mapnik&marker=11.5564,104.9282'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.borderRadius = '16px';
        return iframe;
      });
    }
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredLocations = List.from(allCambodiaLocations));
      return;
    }
    setState(() {
      _filteredLocations = allCambodiaLocations.where((item) {
        return item.provinceKh.toLowerCase().contains(q) ||
            item.provinceEn.toLowerCase().contains(q) ||
            (item.districtKh != null && item.districtKh!.toLowerCase().contains(q)) ||
            (item.districtEn != null && item.districtEn!.toLowerCase().contains(q));
      }).toList();
    });
  }

  Future<void> _fetchGpsLocation() async {
    setState(() {
      _isLocating = true;
      _gpsStatus = 'កំពុងស្វែងរកកូអរដោនេ GPS...';
    });

    if (kIsWeb) {
      try {
        final pos = await html.window.navigator.geolocation.getCurrentPosition();
        final lat = pos.coords?.latitude?.toDouble() ?? 11.5564;
        final lng = pos.coords?.longitude?.toDouble() ?? 104.9282;

        setState(() => _gpsStatus = 'ទទួលបានទីតាំង: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}');

        // Reverse geocode via OpenStreetMap Nominatim
        final nominatimUrl = 'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&accept-language=km,en';
        final res = await html.HttpRequest.getString(nominatimUrl);
        final data = jsonDecode(res);
        final addr = data['address'] as Map<String, dynamic>?;

        String resolvedName = 'កម្ពុជា (Cambodia)';
        if (addr != null) {
          final city = addr['city'] ?? addr['town'] ?? addr['state'] ?? 'ភ្នំពេញ';
          final suburb = addr['suburb'] ?? addr['quarter'] ?? addr['neighbourhood'] ?? addr['village'];
          if (suburb != null) {
            resolvedName = '$suburb, $city';
          } else {
            resolvedName = '$city, កម្ពុជា';
          }
        }

        if (mounted) {
          Navigator.pop(context, resolvedName);
        }
        return;
      } catch (e) {
        setState(() {
          _isLocating = false;
          _gpsStatus = 'មិនអាចទាញយក GPS បានទេ សូមជ្រើសរើសពីបញ្ជី';
        });
      }
    } else {
      setState(() {
        _isLocating = false;
        _gpsStatus = 'ភ្នំពេញ, កម្ពុជា';
      });
      Navigator.pop(context, 'ភ្នំពេញ, កម្ពុជា');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: AppTheme.modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey4,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(CupertinoIcons.location_solid, color: Color(0xFF007AFF), size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('ជ្រើសរើសទីតាំង', 'Select Location'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryText,
                      ),
                    ),
                  ],
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.systemGrey3, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: AppTheme.divider),

          // Segments: List vs Interactive Map
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSegmentedControl<int>(
                selectedColor: const Color(0xFF007AFF),
                unselectedColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE4E6EB),
                borderColor: const Color(0xFF007AFF),
                groupValue: _activeSegment,
                children: {
                  0: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Text(
                      tr('បញ្ជីទីតាំងទាំង ២៥ ខេត្ត-ក្រុង', '25 Provinces List'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  1: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Text(
                      tr('ផែនទីផ្ទាល់ (Map View)', 'Live Map View'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                },
                onValueChanged: (v) => setState(() => _activeSegment = v),
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: CupertinoSearchTextField(
              controller: _searchCtrl,
              placeholder: tr('ស្វែងរក ខេត្ត ស្រុក ខណ្ឌ ភូមិ...', 'Search province, district, village...'),
              onChanged: _onSearch,
              style: TextStyle(color: AppTheme.primaryText),
            ),
          ),

          // GPS Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: GestureDetector(
              onTap: _fetchGpsLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF34C759).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    _isLocating
                        ? const CupertinoActivityIndicator(radius: 9)
                        : const Icon(CupertinoIcons.compass, color: Color(0xFF34C759), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _gpsStatus ?? tr('📍 ប្រើប្រាស់ទីតាំងបច្ចុប្បន្ន (GPS Current Location)', '📍 Use My GPS Current Location'),
                        style: const TextStyle(
                          color: Color(0xFF34C759),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(CupertinoIcons.chevron_forward, color: Color(0xFF34C759), size: 16),
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: _activeSegment == 0
                ? _buildListView()
                : _buildMapView(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: _filteredLocations.length,
      separatorBuilder: (_, __) => Container(height: 0.5, color: AppTheme.divider),
      itemBuilder: (ctx, index) {
        final loc = _filteredLocations[index];
        IconData icon;
        Color iconColor;

        if (loc.type == 'province') {
          icon = CupertinoIcons.building_2_fill;
          iconColor = const Color(0xFF007AFF);
        } else if (loc.type == 'landmark') {
          icon = CupertinoIcons.star_circle_fill;
          iconColor = const Color(0xFFFF9500);
        } else {
          icon = CupertinoIcons.location_solid;
          iconColor = const Color(0xFF34C759);
        }

        return CupertinoListTile(
          padding: const EdgeInsets.symmetric(vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          title: Text(
            loc.displayNameKh,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppTheme.primaryText,
            ),
          ),
          subtitle: Text(
            loc.displayNameEn,
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
          ),
          trailing: const Icon(CupertinoIcons.chevron_forward, size: 16, color: CupertinoColors.systemGrey3),
          onTap: () {
            Navigator.pop(context, loc.displayNameKh);
          },
        );
      },
    );
  }

  Widget _buildMapView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: kIsWeb
                  ? HtmlElementView(viewType: _mapViewType)
                  : Container(
                      color: const Color(0xFF1C1C1E),
                      child: const Center(
                        child: Text(
                          'ផែនទីកម្ពុជា (OpenStreetMap)',
                          style: TextStyle(color: CupertinoColors.white),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('ចុចលើទីតាំងណាមួយលើផែនទី ឬជ្រើសរើសខេត្តខាងក្រោម:', 'Tap anywhere on the map or select a province:'),
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryText),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMapQuickChip('រាជធានីភ្នំពេញ (Phnom Penh)'),
              _buildMapQuickChip('ខេត្តសៀមរាប (Siem Reap)'),
              _buildMapQuickChip('ខេត្តបាត់ដំបង (Battambang)'),
              _buildMapQuickChip('ខេត្តព្រះសីហនុ (Sihanoukville)'),
              _buildMapQuickChip('ខេត្តកំពត (Kampot)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapQuickChip(String label) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF).withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }
}
