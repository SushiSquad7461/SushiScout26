import 'package:flutter/material.dart';
import '../../data/models/match_report.dart';
import '../screens/match_details.dart';

class MatchSearchDelegate extends SearchDelegate<MatchReport?> {
  final List<MatchReport> matches;

  MatchSearchDelegate(this.matches);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildMatchList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildMatchList(context);
  }

  Widget _buildMatchList(BuildContext context) {
    final filteredMatches = matches.where((match) {
      final q = query.toLowerCase();
      return match.matchNumber.toString().contains(q) ||
          match.teamNumber.toString().contains(q) ||
          match.scouterName.toLowerCase().contains(q);
    }).toList();

    if (filteredMatches.isEmpty) {
      return Center(
        child: Text(
          "No matches found",
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredMatches.length,
      itemBuilder: (context, index) {
        final match = filteredMatches[index];
        final allianceColor = match.alliance == 'Red' ? Colors.red : Colors.blue;

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: allianceColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                "${match.matchNumber}",
                style: TextStyle(
                  color: allianceColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          title: Text("Team ${match.teamNumber}"),
          subtitle: Text("Scouted by ${match.scouterName}"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            close(context, null); // Close search
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MatchDetailsScreen(match: match),
              ),
            );
          },
        );
      },
    );
  }
}
