import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
              Text(
                  'Använd en tydlig titel med ämne eller datum, till exempel "Gym – överkropp" eller "Veckans matlådor". Då blir anteckningen lättare att hitta med sök. Håll inne en anteckning på startsidan för att flytta, dela, visa detaljer eller radera den.'),
              Text(
                  'Skapa gärna kategorier som Träning, Recept och Dagbok. Kategorier hjälper dig att bläddra bland relaterade anteckningar; sök hittar även text inne i anteckningarna.'),
            ],
          ),
          _GuideSection(
            title: 'Träningslogg',
            icon: Icons.fitness_center,
            children: [
              Text(
                  'Skapa en anteckning per pass, eller en per vecka om du vill samla flera pass. Skriv datum och passets namn i titeln. Lägg övningar, set, repetitioner och vikt i innehållet. Vill du hålla anteckningen kompakt? Tryck på träningsikonen i verktygsfältet för ett expanderbart övningskort.'),
              _CopyableExample(
                text: 'Helkropp – 2026-11-18\n'
                    'Känsla: bra\n'
                    '\n'
                    'Knäböj\n'
                    '- 60 kg × 8\n'
                    '- 60 kg × 8\n'
                    '- 60 kg × 7\n'
                    '\n'
                    'Bänkpress\n'
                    '- 40 kg × 10\n'
                    '- 40 kg × 9\n'
                    '\n'
                    'Notering: höj vikten lite nästa gång.',
              ),
              Text(
                  'Skriv gärna vilodagar, personbästa, smärta eller ändringar i en kort notering. Sök sedan på övningsnamn, vikt eller en fras ur noteringen.'),
            ],
          ),
          _GuideSection(
            title: 'Recept och måltider',
            icon: Icons.restaurant_menu,
            children: [
              Text(
                  'Spara ett recept per anteckning. Använd titeln för rätten och en kategori som Recept. Ange portioner och tillagningstid, skriv ingredienser som lista och numrera momenten i tillagningsordning.'),
              _CopyableExample(
                text: 'Ugnslax med potatis\n'
                    'Portioner: 2 | Tid: 30 min\n'
                    '\n'
                    'Ingredienser\n'
                    '- 2 laxfiléer\n'
                    '- 500 g potatis\n'
                    '- 1 citron\n'
                    '- Salt, peppar och dill\n'
                    '\n'
                    'Gör så här\n'
                    '1. Sätt ugnen på 200 °C.\n'
                    '2. Dela potatisen och rosta i cirka 20 min.\n'
                    '3. Lägg in laxen de sista 12–15 min.\n'
                    '4. Servera med citron och dill.\n'
                    '\n'
                    'Ändringar: fungerade bra med broccoli.',
              ),
              Text(
                  'Lägg gärna till egna byten, allergener eller hur receptet blev. Sök på ingredienser när du vill hitta recept utifrån det du har hemma.'),
            ],
          ),
          _GuideSection(
            title: 'Dagliga anteckningar',
            icon: Icons.today_outlined,
            children: [
              Text(
                  'Skriv en kort anteckning per dag, eller samla dagen i en återkommande anteckning. Datum i titeln gör det enkelt att hitta en viss dag. Anteckna sådant du vill komma ihåg: händelser, idéer, planer eller en kort reflektion.'),
              _CopyableExample(
                text: '2026-11-18\n'
                    '\n'
                    'Idag\n'
                    '- Färdigställde veckans planering\n'
                    '- Tog en promenad efter jobbet\n'
                    '\n'
                    'Att komma ihåg\n'
                    '- Boka tid på fredag\n'
                    '\n'
                    'Imorgon\n'
                    '- Handla ingredienser till middagen',
              ),
              Text(
                  'Du behöver inte fylla i varje rubrik. En eller två meningar räcker. Sök senare på ett namn, en plats eller något du skrev ned.'),
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
            title: 'Kalender',
            icon: Icons.calendar_month_outlined,
            children: [
              Text(
                  'Skriv till exempel “08:00 start zo 25mg” eller “stop zo 25 apa”; kalendern visar “zo 25mg” respektive “zo 25”. Stop är valfritt. Tidsintervall visas när båda raderna har klockslag.'),
              Text(
                  'Välj en dag för att se hur länge sedan den var. Sök på en del av namnet, till exempel “zo”, eller välj en aktivitet från listan. Tryck på en rad för att öppna anteckningen.'),
            ],
          ),
          _GuideSection(
            title: 'Redigering',
            icon: Icons.edit_note,
            children: [
              Text(
                  'Snabbknapparna innehåller bland annat länk, sök, textstorlek, textstil, avdelare och kopiera formaterad text. Punktlistor och checklistor kan indenteras med knapparna för öka/minska indrag. Tryck på ⋯ för fler verktyg, till exempel kursiv, genomstrykning, färger, justering och kodblock. Tryck på texten för att placera markören.'),
              Text(
                  'Markera text och välj Insert URL för att göra den till en länk. Med en markör utan markering kan du skriva länktexten och adressen, så infogas länken där markören står. Knappen skapar länkar men redigerar inte redan befintliga länkar.'),
              Text(
                  'Markera ett ord eller en fras och tryck på Comments för att starta en kommentarstråd. Du kan svara direkt i tråden.'),
              Text('På mobil öppnas länkens meny med ett långt tryck.'),
              Text(
                  'I Settings kan du aktivera automatisk redigering av befintliga anteckningar och välja en genväg som infogar aktuell tid.'),
            ],
          ),
          _GuideSection(
            title: 'Tabell i en anteckning',
            icon: Icons.table_chart_outlined,
            children: [
              Text(
                  'Du kan göra en enkel, fastbreddstabell med text. Öppna ⋯, välj kodblock och skriv tabellen med tecken som +, - och |. Kodblocket använder fast teckenbredd så kolumnerna hålls raka.'),
              _CopyableExample(
                text: '+--------+----------+\n'
                    '| Uppgift | Status   |\n'
                    '+--------+----------+\n'
                    '| Exempel | Klar     |\n'
                    '+--------+----------+',
                monospace: true,
              ),
              Text(
                  'Detta är en visuell texttabell, inte ett kalkylblad: celler kan inte sorteras eller redigeras separat. Håll tabellen kort för att den ska fungera bra på mobilskärmen.'),
              Text(
                  'Kodblock passar också för kod, kommandon och text där radbrytningar och mellanrum behöver bevaras. För vanlig text kan du använda textstil och listknapparna i verktygsraden.'),
              Text(
                  'Tryck på Kopiera exempel för att kopiera en mall. Du kan också markera texten direkt. Klistra sedan in den i en anteckning och ändra den efter behov.'),
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
              Text(
                  'Exportera regelbundet och förvara en kopia på en annan plats. Kontrollera att du minns lösenordet innan du behöver återställa en säkerhetskopia.'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CopyableExample extends StatelessWidget {
  const _CopyableExample({
    required this.text,
    this.monospace = false,
  });

  final String text;
  final bool monospace;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exemplet kopierat')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Kopiera exempel'),
            ),
          ),
          SelectableText(
            text,
            style: monospace
                ? const TextStyle(fontFamily: 'monospace', fontSize: 12)
                : null,
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
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            children[index],
          ],
        ],
      ),
    );
  }
}
