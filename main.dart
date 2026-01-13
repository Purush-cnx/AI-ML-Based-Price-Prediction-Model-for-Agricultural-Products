import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() => runApp(const FarmAssistApp());

//  Change this when testing on Android
const String baseUrl = "http://127.0.0.1:5000";

class FarmAssistApp extends StatelessWidget {
  const FarmAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmAssist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32), brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF7FAF7),
        useMaterial3: true,
      ),
      home: const HomeTabs(),
    );
  }
}


//  Home with 4 Tabs

class HomeTabs extends StatelessWidget {
  const HomeTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFE8F5E9),
          title: const Text("FarmAssist", style: TextStyle(fontWeight: FontWeight.w700)),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Color(0xFF1B5E20),
            indicatorColor: Color(0xFF2E7D32),
            tabs: [
              Tab(icon: Icon(Icons.currency_rupee), text: "Price"),
              Tab(icon: Icon(Icons.agriculture), text: "Crop"),
              Tab(icon: Icon(Icons.biotech), text: "Fertilizer"),
              Tab(icon: Icon(Icons.local_hospital), text: "Disease"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [PriceTab(), CropTab(), FertilizerTab(), DiseaseTab()],
        ),
      ),
    );
  }
}


//  Reusable Components

class CenteredPanel extends StatelessWidget {
  final Widget child;
  const CenteredPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final String title;
  final Widget child;
  const GlassCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF2E7D32), fontSize: 16)),
          const SizedBox(height: 10),
          child,
        ]),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  const PrimaryButton({super.key, required this.text, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: Icon(icon),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        onPressed: onPressed,
      ),
    );
  }
}

class OutputBox extends StatelessWidget {
  final String text;
  const OutputBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBDDBB)),
      ),
      child: SelectableText(
        text.isEmpty ? "Output will appear here..." : text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      ),
    );
  }
}


//  Voice Input (Auto Capitalize)

class VoiceInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  const VoiceInputField({super.key, required this.controller, required this.label, this.keyboard});

  @override
  State<VoiceInputField> createState() => _VoiceInputFieldState();
}

class _VoiceInputFieldState extends State<VoiceInputField> {
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _listen() async {
    if (!_isListening) {
      if (await _speech.initialize()) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          final spoken = result.recognizedWords.trim();
          final formatted = spoken
              .split(" ")
              .map((w) => w.isEmpty ? "" : w[0].toUpperCase() + w.substring(1).toLowerCase())
              .join(" ");
          setState(() => widget.controller.text = formatted);
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboard,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          onPressed: _listen,
          icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: const Color(0xFF2E7D32)),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}


//  Price Tab

class PriceTab extends StatefulWidget {
  const PriceTab({super.key});
  @override
  State<PriceTab> createState() => _PriceTabState();
}
 
class _PriceTabState extends State<PriceTab> {
  final state = TextEditingController();
  final district = TextEditingController();
  final commodity = TextEditingController();
  final weight = TextEditingController();
  final cost = TextEditingController();
  String result = "";

  Future<void> _predict() async {
    final body = jsonEncode({
      "state": state.text,
      "district": district.text,
      "commodity": commodity.text,
      "weight": double.tryParse(weight.text) ?? 1,
      "cost": double.tryParse(cost.text) ?? 0,
    });
    final res = await http.post(Uri.parse("$baseUrl/predict_market"),
        headers: {"Content-Type": "application/json"}, body: body);
    setState(() => result = res.statusCode == 200
        ? (jsonDecode(res.body)['formatted_output'] ?? "No output")
        : "Error: ${res.body}");
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: CenteredPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              title: "Input",
              child: Column(children: [
                Row(children: [
                  Expanded(child: VoiceInputField(controller: state, label: "State")),
                  const SizedBox(width: 10),
                  Expanded(child: VoiceInputField(controller: district, label: "District")),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: VoiceInputField(controller: commodity, label: "Commodity")),
                  const SizedBox(width: 10),
                  Expanded(child: VoiceInputField(controller: weight, label: "Weight (qtl)", keyboard: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                VoiceInputField(controller: cost, label: "Cost per Quintal (₹)", keyboard: TextInputType.number),
                const SizedBox(height: 10),
                PrimaryButton(text: "Predict Price", icon: Icons.trending_up, onPressed: _predict),
              ]),
            ),
            const SizedBox(height: 12),
            GlassCard(title: "Output", child: OutputBox(text: result)),
          ],
        ),
      ),
    );
  }
}


//  Crop Tab

class CropTab extends StatefulWidget {
  const CropTab({super.key});
  @override
  State<CropTab> createState() => _CropTabState();
}

class _CropTabState extends State<CropTab> {
  final N = TextEditingController();
  final P = TextEditingController();
  final K = TextEditingController();
  final ph = TextEditingController();
  final district = TextEditingController();
  String result = "";

  Future<void> _recommend() async {
    final body = jsonEncode({
      "N": double.tryParse(N.text) ?? 0,
      "P": double.tryParse(P.text) ?? 0,
      "K": double.tryParse(K.text) ?? 0,
      "ph": double.tryParse(ph.text) ?? 7,
      "district": district.text,
    });
    final res = await http.post(Uri.parse("$baseUrl/predict_crop"),
        headers: {"Content-Type": "application/json"}, body: body);
    setState(() => result = res.statusCode == 200
        ? (jsonDecode(res.body)['formatted_output'] ?? "No output")
        : "Error: ${res.body}");
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: CenteredPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              title: "Input",
              child: Column(children: [
                Row(children: [
                  Expanded(child: VoiceInputField(controller: N, label: "Nitrogen (N)", keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: VoiceInputField(controller: P, label: "Phosphorus (P)", keyboard: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: VoiceInputField(controller: K, label: "Potassium (K)", keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: VoiceInputField(controller: ph, label: "pH Value", keyboard: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                VoiceInputField(controller: district, label: "District / City"),
                const SizedBox(height: 10),
                PrimaryButton(text: "Recommend Crop", icon: Icons.agriculture, onPressed: _recommend),
              ]),
            ),
            const SizedBox(height: 12),
            GlassCard(title: "Output", child: OutputBox(text: result)),
          ],
        ),
      ),
    );
  }
}


//  Fertilizer Tab

class FertilizerTab extends StatefulWidget {
  const FertilizerTab({super.key});
  @override
  State<FertilizerTab> createState() => _FertilizerTabState();
}

class _FertilizerTabState extends State<FertilizerTab> {
  final crop = TextEditingController();
  final N = TextEditingController();
  final P = TextEditingController();
  final K = TextEditingController();
  String result = "";

  Future<void> _recommend() async {
    final body = jsonEncode({
      "crop": crop.text,
      "N": double.tryParse(N.text) ?? 0,
      "P": double.tryParse(P.text) ?? 0,
      "K": double.tryParse(K.text) ?? 0,
    });
    final res = await http.post(Uri.parse("$baseUrl/predict_fertilizer"),
        headers: {"Content-Type": "application/json"}, body: body);
    setState(() => result = res.statusCode == 200
        ? (jsonDecode(res.body)['formatted_output'] ?? "No output")
        : "Error: ${res.body}");
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: CenteredPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              title: "Input",
              child: Column(children: [
                VoiceInputField(controller: crop, label: "Crop Name"),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: VoiceInputField(controller: N, label: "Nitrogen (N)", keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: VoiceInputField(controller: P, label: "Phosphorus (P)", keyboard: TextInputType.number)),
                ]),
                const SizedBox(height: 10),
                VoiceInputField(controller: K, label: "Potassium (K)", keyboard: TextInputType.number),
                const SizedBox(height: 10),
                PrimaryButton(text: "Recommend Fertilizer", icon: Icons.biotech, onPressed: _recommend),
              ]),
            ),
            const SizedBox(height: 12),
            GlassCard(title: "Output", child: OutputBox(text: result)),
          ],
        ),
      ),
    );
  }
}


//  Disease Tab (Placeholder)

class DiseaseTab extends StatelessWidget {
  const DiseaseTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: CenteredPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            GlassCard(
              title: "Input",
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Upload image & detect disease (Coming soon)."),
              ),
            ),
            SizedBox(height: 12),
            GlassCard(title: "Output", child: OutputBox(text: "")),
          ],
        ),
      ),
    );
  }
}
