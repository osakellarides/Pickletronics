import 'package:flutter/material.dart';
import 'session_parser.dart';
import 'session_detail_view.dart';
import 'package:intl/intl.dart';

class SessionsTab extends StatefulWidget {
  const SessionsTab({super.key});

  @override
  _SessionsTabState createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  List<Session> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _deleteSession(int displayedIndex) async {
  int actualIndex = _sessions.length - 1 - displayedIndex;
  await SessionParser().deleteSession(actualIndex);
  _loadSessions();

  // Notify StartGameView that sessions were updated
  if (mounted) {
    setState(() {}); // Ensure UI updates
  }
}

  void _notifyDashboard() {
    Navigator.of(context).pop(); // Close dialog
    if (Navigator.canPop(context)) {
      Navigator.pop(context); // Ensure dashboard updates if user navigates back
    }
  }

  Future<void> _loadSessions() async {
      List<Session> sessions = await SessionParser().loadSessions();
      setState(() {
        _sessions = sessions.reversed.toList(); // Reverse order: newest first
      });
  }

  void _confirmDeleteSession(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Session"),
          content: const Text("Are you sure you want to delete this session?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancel
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await _deleteSession(index);
                Navigator.pop(context);
              },
              child: const Text("Delete", style: TextStyle(color: Color.fromARGB(255, 0, 0, 0))),
            ),
          ],
        );
      },
    );
  }

  // Refresh sessions when coming back to the screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSessions(); // Reload sessions every time UI is shown
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sessions")),
      body: _sessions.isEmpty
          ? Center(child: const Text("No sessions recorded."))
          : ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                int displayedSessionNumber = _sessions.length - index;
                
                return ListTile(
                  title: Text("Session $displayedSessionNumber"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sessions[index].timestamp != null
                            ? DateFormat("MMMM d, y h:mm a").format(_sessions[index].timestamp!)
                            : "Unknown Date",
                      )
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_forever, color: Color.fromARGB(255, 78, 78, 78)),
                    onPressed: () => _confirmDeleteSession(index),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SessionDetailsPage(
                          session: _sessions[index],
                          displayedSessionNumber: displayedSessionNumber,
                        ),
                      ),
                    ).then((_) => _loadSessions()); // Reload sessions when returning
                  },
                );
              },
            ),
    );
  }
}
