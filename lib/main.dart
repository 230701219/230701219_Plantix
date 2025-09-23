import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CropCare - Plant Disease Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: MaterialColor(0xFF4CAF50, {
          50: const Color(0xFFE8F5E8),
          100: const Color(0xFFC8E6C9),
          200: const Color(0xFFA5D6A7),
          300: const Color(0xFF81C784),
          400: const Color(0xFF66BB6A),
          500: const Color(0xFF4CAF50),
          600: const Color(0xFF43A047),
          700: const Color(0xFF388E3C),
          800: const Color(0xFF2E7D32),
          900: const Color(0xFF1B5E20),
        }),
        scaffoldBackgroundColor: const Color(0xFFF8FFF8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.green.withOpacity(0.2),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TfliteModelService _tfliteService = TfliteModelService();
  final ImagePicker _picker = ImagePicker();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  XFile? _image;
  String? _prediction;
  String? _pesticide;
  bool _isLoading = false;
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _initializeModel();
  }

  Future<void> _initializeModel() async {
    await _tfliteService.loadModel();
    setState(() {
      _modelLoaded = true;
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image != null) {
      _processImage(image);
    }
  }

  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      _processImage(image);
    }
  }

  Future<void> _processImage(XFile image) async {
    setState(() {
      _isLoading = true;
      _image = image;
      _prediction = null;
      _pesticide = null;
    });

    try {
      final imageBytes = await image.readAsBytes();
      final prediction = await _tfliteService.predict(imageBytes);
      final pesticide = _getPesticideForDisease(prediction);

      setState(() {
        _prediction = prediction;
        _pesticide = pesticide;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error processing image: $e');
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Wrap(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Select Image Source',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildImageSourceOption(
                          icon: Icons.camera_alt,
                          label: 'Camera',
                          onTap: () {
                            Navigator.pop(context);
                            _pickImageFromCamera();
                          },
                        ),
                        _buildImageSourceOption(
                          icon: Icons.photo_library,
                          label: 'Gallery',
                          onTap: () {
                            Navigator.pop(context);
                            _pickImageFromGallery();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4CAF50).withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: const Color(0xFF4CAF50),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _findPesticideShops() async {
    const String googleMapsUrl = 'https://www.google.com/maps/search/pesticide+shops+near+me';
    
    try {
      final Uri uri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorDialog('Could not open Google Maps. Please ensure Google Maps is installed.');
      }
    } catch (e) {
      _showErrorDialog('Error opening Google Maps: $e');
    }
  }

  String _getPesticideForDisease(String? disease) {
    if (disease == null) return "Could not determine treatment.";

    if (disease.toLowerCase().endsWith('___healthy')) {
      return '🌱 Great news! Your plant appears to be healthy. Continue with regular care and monitoring.';
    }

    switch (disease.toLowerCase()) {
      // Apple Diseases
      case 'apple___apple_scab':
        return '🍎 Apply fungicides like Captan, Myclobutanil, or sulfur-based sprays. Ensure good air circulation by pruning infected branches.';
      case 'apple___black_rot':
        return '🍎 Prune out infected branches immediately. Apply fungicides like Captan or Thiophanate-methyl during the growing season.';
      case 'apple___cedar_apple_rust':
        return '🍎 Apply fungicides like Myclobutanil or Mancozeb. Remove nearby cedar trees if possible to break the disease cycle.';

      // Cherry Disease
      case 'cherry_(including_sour)___powdery_mildew':
        return '🍒 Apply sulfur-based fungicides or potassium bicarbonate. Improve air circulation around plants.';

      // Corn (Maize) Diseases
      case 'corn_(maize)___cercospora_leaf_spot gray_leaf_spot':
        return '🌽 Use fungicides containing Pyraclostrobin or Azoxystrobin. Implement crop rotation for long-term management.';
      case 'corn_(maize)___common_rust_':
        return '🌽 Apply fungicides like Propiconazole or Tebuconazole if detected early on susceptible hybrids.';
      case 'corn_(maize)___northern_leaf_blight':
        return '🌽 Apply fungicides containing Azoxystrobin or Propiconazole. Consider planting resistant hybrids next season.';

      // Grape Diseases
      case 'grape___black_rot':
        return '🍇 Apply fungicides like Mancozeb or Myclobutanil. Remove and destroy infected grapes and plant debris.';
      case 'grape___esca_(black_measles)':
        return '🍇 No effective chemical treatment available. Focus on proper pruning techniques to remove infected vine parts.';
      case 'grape___leaf_blight_(isariopsis_leaf_spot)':
        return '🍇 Apply copper-based fungicides. Ensure proper canopy management for adequate air circulation.';

      // Orange Disease
      case 'orange___haunglongbing_(citrus_greening)':
        return '🍊 No cure available. Remove infected trees and control Asian citrus psyllid with appropriate insecticides.';

      // Peach Disease
      case 'peach___bacterial_spot':
        return '🍑 Apply copper-based bactericides during dormant season. Consider planting resistant varieties.';

      // Pepper Disease
      case 'pepper,_bell___bacterial_spot':
        return '🌶️ Apply copper-based bactericides. Rotate crops and avoid overhead watering to prevent spread.';

      // Potato Diseases
      case 'potato___early_blight':
        return '🥔 Apply fungicides like Chlorothalonil or Mancozeb. Practice crop rotation and remove infected plant debris.';
      case 'potato___late_blight':
        return '🥔 Apply fungicides like Chlorothalonil or copper-based sprays, especially during cool, moist weather conditions.';

      // Squash Disease
      case 'squash___powdery_mildew':
        return '🎃 Apply sulfur-based fungicides, neem oil, or potassium bicarbonate. Ensure good air circulation.';

      // Strawberry Disease
      case 'strawberry___leaf_scorch':
        return '🍓 Apply fungicides containing Captan or Thiram after harvest. Remove old, infected leaves promptly.';

      // Tomato Diseases
      case 'tomato___bacterial_spot':
        return '🍅 Use copper-based bactericides. Avoid working with plants when wet and ensure proper plant spacing.';
      case 'tomato___early_blight':
        return '🍅 Apply fungicides like Chlorothalonil or Mancozeb. Mulch around plants to prevent soil splash.';
      case 'tomato___late_blight':
        return '🍅 Apply fungicides containing Mancozeb or Chlorothalonil, especially during cool, wet weather.';
      case 'tomato___leaf_mold':
        return '🍅 Apply fungicides like Chlorothalonil. Reduce humidity and ensure good air circulation.';
      case 'tomato___septoria_leaf_spot':
        return '🍅 Apply fungicides containing Chlorothalonil or copper. Remove lower infected leaves regularly.';
      case 'tomato___spider_mites two-spotted_spider_mite':
        return '🍅 Use miticides, insecticidal soap, or neem oil. Focus treatment on leaf undersides where mites congregate.';
      case 'tomato___target_spot':
        return '🍅 Apply fungicides like Chlorothalonil or Mancozeb. Stake plants properly for better air circulation.';
      case 'tomato___tomato_yellow_leaf_curl_virus':
        return '🍅 No cure for viral disease. Control whitefly vectors with insecticides like imidacloprid.';
      case 'tomato___tomato_mosaic_virus':
        return '🍅 No cure for viral disease. Practice strict sanitation and remove infected plants immediately.';

      default:
        return '🔍 No specific treatment recommendation found. Please consult your local agricultural extension office or plant pathologist for expert advice.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🌱 Plantix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(),
          ),
        ],
      ),
      body: !_modelLoaded
          ? _buildLoadingScreen()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildMainContent(),
              ),
            ),
      floatingActionButton: _modelLoaded && _prediction != null
          ? FloatingActionButton.extended(
              onPressed: _findPesticideShops,
              backgroundColor: const Color(0xFF2E7D32),
              icon: const Icon(Icons.location_on, color: Colors.white),
              label: const Text(
                'Find Shops',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            strokeWidth: 3,
          ),
          SizedBox(height: 24),
          Text(
            'Loading AI Model...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2E7D32),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Please wait while we prepare the plant disease detection system',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 24),
          if (_image != null) _buildImagePreview(),
          if (_image != null) const SizedBox(height: 24),
          _buildActionButton(),
          const SizedBox(height: 24),
          if (_isLoading) _buildLoadingIndicator(),
          if (_prediction != null && !_isLoading) _buildResultsCard(),
          const SizedBox(height: 100), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF4CAF50).withOpacity(0.1),
              const Color(0xFF81C784).withOpacity(0.1),
            ],
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.eco,
              size: 48,
              color: Color(0xFF2E7D32),
            ),
            SizedBox(height: 16),
            Text(
              'Plant Disease Detection',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Upload a photo of your plant to detect diseases and get treatment recommendations',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Selected Image',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_image!.path),
                height: 250,
                width: 250,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return Container(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _showImagePickerOptions,
        icon: const Icon(Icons.add_a_photo, size: 24),
        label: Text(
          _image == null ? 'Select Plant Image' : 'Change Image',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: const Column(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
              strokeWidth: 3,
            ),
            SizedBox(height: 20),
            Text(
              'Analyzing your plant...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2E7D32),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Our AI is examining the image for diseases',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    final isHealthy = _prediction!.toLowerCase().endsWith('___healthy');
    
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isHealthy ? Icons.check_circle : Icons.warning,
                  color: isHealthy ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Analysis Results',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isHealthy ? const Color(0xFF4CAF50) : const Color(0xFFFF9800)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isHealthy ? const Color(0xFF4CAF50) : const Color(0xFFFF9800)).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detected Condition:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _prediction!.replaceAll('___', ' - ').replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isHealthy ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            const Text(
              'Recommended Action:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withOpacity(0.2),
                ),
              ),
              child: Text(
                _pesticide!,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.eco, color: Color(0xFF4CAF50)),
              SizedBox(width: 8),
              Text('About CropCare'),
            ],
          ),
          content: const Text(
            'CropCare is an AI-powered plant disease detection app designed specifically for farmers. Simply take a photo of your plant, and our advanced machine learning model will identify potential diseases and provide treatment recommendations.\n\n'
            'Features:\n'
            '• Instant disease detection\n'
            '• Treatment recommendations\n'
            '• Find nearby pesticide shops\n'
            '• Works offline after initial setup',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }
}

/// -------------------------------------------------------------------
/// TFLite Model Service - unchanged from original
/// -------------------------------------------------------------------
class TfliteModelService {
  Interpreter? _interpreter;
  List<String>? _labels;

  Future<void> loadModel() async {
    try {
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData.split('\n').map((label) => label.trim()).toList();
      _interpreter = await Interpreter.fromAsset('assets/plant_disease_model.tflite');
      print('✅ Model and labels loaded successfully.');
    } catch (e) {
      print('❌ Error loading model: $e');
    }
  }

  Future<String?> predict(Uint8List imageBytes) async {
    if (_interpreter == null || _labels == null) {
      print('Model not loaded.');
      return null;
    }

    var inputImage = _preprocessImage(imageBytes);
    var input = inputImage.reshape([1, 224, 224, 3]);
    var output = List.filled(1 * _labels!.length, 0.0).reshape([1, _labels!.length]);
    _interpreter!.run(input, output);

    var outputScores = output[0] as List<double>;
    var maxScore = 0.0;
    var maxScoreIndex = -1;
    for (int i = 0; i < outputScores.length; i++) {
      if (outputScores[i] > maxScore) {
        maxScore = outputScores[i];
        maxScoreIndex = i;
      }
    }
    return maxScoreIndex != -1 ? _labels![maxScoreIndex] : null;
  }

  Float32List _preprocessImage(Uint8List imageBytes) {
    img.Image? originalImage = img.decodeImage(imageBytes);
    img.Image resizedImage = img.copyResize(originalImage!, width: 224, height: 224);

    var buffer = Float32List(1 * 224 * 224 * 3);
    var bufferIndex = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        var pixel = resizedImage.getPixel(x, y);
        buffer[bufferIndex++] = pixel.r.toDouble() / 255.0;
        buffer[bufferIndex++] = pixel.g.toDouble() / 255.0;
        buffer[bufferIndex++] = pixel.b.toDouble() / 255.0;
      }
    }
    return buffer;
  }
}