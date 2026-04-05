import 'package:flutter/material.dart';
import '../../core/gluconav_colors.dart';
import '../../services/gluconav_api_service.dart';
import '../../main.dart'; // To navigate to GlucoNavShell

class GlucoOnboardingScreen extends StatefulWidget {
  const GlucoOnboardingScreen({super.key});

  @override
  State<GlucoOnboardingScreen> createState() => _GlucoOnboardingScreenState();
}

class _GlucoOnboardingScreenState extends State<GlucoOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // State variables for form
  int? age;
  double? weightKg;
  double? heightCm;
  String? gender;
  String? goal;
  String? activityLevel;
  String? diabetesType;
  String? hba1cBand;
  String? cuisinePreference;
  String? dietType;

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitForm();
    }
  }

  void _submitForm() async {
    // Basic validation / defaults for missing fields
    final payload = {
      "diabetes_type": diabetesType ?? "type2",
      "hba1c_band": hba1cBand ?? "moderate",
      "cuisine_preference": cuisinePreference ?? "south_indian",
      "diet_type": dietType ?? "vegetarian",
      "age": age ?? 30,
      "weight_kg": weightKg ?? 70.0,
      "height_cm": heightCm ?? 170.0,
      "gender": gender ?? "male",
      "goal": goal ?? "maintain",
      "activity_level": activityLevel ?? "sedentary"
    };

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      
      final newUserId = await GlucoNavApiService().onboardUser(payload);
      
      if (!mounted) return;
      Navigator.pop(context); // pop loading

      if (newUserId != null) {
        await GlucoNavApiService.setUserId(newUserId);
        
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GlucoNavShell()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  Widget _buildOptionTile(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? GlucoNavColors.primary.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? GlucoNavColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? GlucoNavColors.textPrimary : Colors.grey.shade700,
                ),
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: GlucoNavColors.primary),
          ],
        ),
      ),
    );
  }

// We will build a beautiful 4-page UI.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlucoNavColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Bar
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage >= index ? GlucoNavColors.primary : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  // PAGE 0: Basic Bio
                  _buildPage(
                    title: "Let's know you better",
                    subtitle: "Personalize your GlucoNav experience.",
                    content: Column(
                      children: [
                        TextFormField(
                          keyboardType: TextInputType.number,
                          decoration: _inputDeco("Age (Years)"),
                          onChanged: (v) => age = int.tryParse(v),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: TextFormField(
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco("Weight (kg)"),
                              onChanged: (v) => weightKg = double.tryParse(v),
                            )),
                            const SizedBox(width: 16),
                            Expanded(child: TextFormField(
                              keyboardType: TextInputType.number,
                              decoration: _inputDeco("Height (cm)"),
                              onChanged: (v) => heightCm = double.tryParse(v),
                            )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildOptionTile("Male", gender == "male", () => setState(() => gender = "male")),
                        _buildOptionTile("Female", gender == "female", () => setState(() => gender = "female")),
                      ],
                    ),
                  ),

                  // PAGE 1: Diabetes & Kitchen
                  _buildPage(
                    title: "Medical & Diet",
                    subtitle: "Help us understand your metabolic profile.",
                    content: Column(
                      children: [
                        Text("Diabetes Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        _buildOptionTile("Type 2 Diabetes", diabetesType == "type2", () => setState(() => diabetesType = "type2")),
                        _buildOptionTile("Type 1 Diabetes", diabetesType == "type1", () => setState(() => diabetesType = "type1")),
                        _buildOptionTile("Pre-diabetes", diabetesType == "prediabetes", () => setState(() => diabetesType = "prediabetes")),
                        const SizedBox(height: 24),
                        Text("HbA1c Band", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        _buildOptionTile("Controlled (Under 7%)", hba1cBand == "controlled", () => setState(() => hba1cBand = "controlled")),
                        _buildOptionTile("Moderate (7% - 8.5%)", hba1cBand == "moderate", () => setState(() => hba1cBand = "moderate")),
                        _buildOptionTile("Uncontrolled (Above 8.5%)", hba1cBand == "uncontrolled", () => setState(() => hba1cBand = "uncontrolled")),
                      ],
                    ),
                  ),

                  // PAGE 2: Food Preferences
                  _buildPage(
                    title: "What do you like to eat?",
                    subtitle: "Customize meal recommendations to your taste.",
                    content: Column(
                      children: [
                        Text("Cuisine Preference", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        _buildOptionTile("South Indian", cuisinePreference == "south_indian", () => setState(() => cuisinePreference = "south_indian")),
                        _buildOptionTile("North Indian", cuisinePreference == "north_indian", () => setState(() => cuisinePreference = "north_indian")),
                        _buildOptionTile("Global / Mediterranean", cuisinePreference == "global", () => setState(() => cuisinePreference = "global")),
                        const SizedBox(height: 24),
                        Text("Diet Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        _buildOptionTile("Vegetarian", dietType == "vegetarian", () => setState(() => dietType = "vegetarian")),
                        _buildOptionTile("Non-Vegetarian", dietType == "non_vegetarian", () => setState(() => dietType = "non_vegetarian")),
                        _buildOptionTile("Vegan", dietType == "vegan", () => setState(() => dietType = "vegan")),
                      ],
                    ),
                  ),

                  // PAGE 3: Goals
                  _buildPage(
                    title: "Activity & Goals",
                    subtitle: "Finish setting up your plan.",
                    content: Column(
                      children: [
                        Text("Typical Activity Level", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        _buildOptionTile("Sedentary (Little to no exercise)", activityLevel == "sedentary", () => setState(() => activityLevel = "sedentary")),
                        _buildOptionTile("Lightly Active", activityLevel == "light", () => setState(() => activityLevel = "light")),
                        _buildOptionTile("Very Active", activityLevel == "active", () => setState(() => activityLevel = "active")),
                        const SizedBox(height: 24),
                        Text("Your Primary Goal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        _buildOptionTile("Lose Weight", goal == "lose_weight", () => setState(() => goal = "lose_weight")),
                        _buildOptionTile("Maintain Weight", goal == "maintain", () => setState(() => goal = "maintain")),
                        _buildOptionTile("Gain Muscle", goal == "gain", () => setState(() => goal = "gain")),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Nav Shell
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(_currentPage == 3 ? "Complete" : "Continue", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      fillColor: Colors.white,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildPage({required String title, required String subtitle, required Widget content}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: GlucoNavColors.textPrimary)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 32),
          content,
        ],
      ),
    );
  }
}
