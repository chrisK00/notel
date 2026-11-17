import 'package:flutter/material.dart';

class UserGuidePage extends StatelessWidget {
  const UserGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Användarguide'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _GuideSection(
            title: 'Anteckningar',
            icon: Icons.note_alt_outlined,
            children: [
              Text(
                  'Tryck på + för att skapa en anteckning. Öppna en anteckning genom att trycka på den i listan.'),
              Text(
                  'Skriv en titel och innehåll. Använd Save för att spara. Om du går tillbaka med osparade ändringar får du välja om de ska sparas eller ignoreras.'),
              Text(
                  'Tryck på datumet eller välj datum i menyn med tre punkter. Där finns även delning, kategorival och borttagning.'),
            ],
          ),
          _GuideSection(
            title: 'Kategorier',
            icon: Icons.folder_outlined,
            children: [
              Text(
                  'Öppna Categories längst ned och tryck på + för att skapa en kategori. Dra i listan för att ändra ordning.'),
              Text(
                  'Öppna en kategori för att visa dess anteckningar. Menyn vid kategorinamnet innehåller sortering och visningsval. Du kan också tilldela en kategori från anteckningens meny.'),
            ],
          ),
          _GuideSection(
            title: 'Sök',
            icon: Icons.search,
            children: [
              Text(
                  'Skriv i sökrutan för att söka i anteckningarna. Tryck på filterikonen för exempel och hjälp med sökfilter.'),
              Text(
                  'Exempel: title:rapport söker i titlar, date:2025-01-01..2025-01-31 söker mellan datum och modified:2025-08 söker efter senast ändrade under månaden.'),
              Text(
                  'Du kan kombinera ord med && (alla ord måste finnas), || (något av orden räcker) och -ord för att utesluta ett ord.'),
            ],
          ),
          _GuideSection(
            title: 'Redigering',
            icon: Icons.edit_note,
            children: [
              Text(
                  'Verktygsraden i anteckningen innehåller formatering, rubriker, länkar, avdelare och ångra/gör om. Tryck på texten för att placera markören.'),
              Text(
                  'I Settings kan du aktivera automatisk redigering av befintliga anteckningar och välja en genväg som infogar aktuell tid.'),
            ],
          ),
          _GuideSection(
            title: 'Säkerhetskopior',
            icon: Icons.backup_outlined,
            children: [
              Text(
                  'I Settings > Backup kan du exportera eller importera en krypterad säkerhetskopia. Veckovis säkerhetskopiering kräver en vald mapp och ett lösenord.'),
              Text(
                  'Spara lösenordet säkert. Utan det går det inte att läsa in den krypterade säkerhetskopian.'),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              children[index],
            ],
          ],
        ),
      ),
    );
  }
}
