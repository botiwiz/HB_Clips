import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About HB_Clips')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dashboard_customize_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'HB_Clips',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Created by Boti Harko',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                if (info == null) return const SizedBox.shrink();
                return Text(
                  'Version ${info.version}+${info.buildNumber}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
