import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<Map<String, dynamic>> buyers = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String myEmail = '';

  @override
  void initState() {
    super.initState();
    _fetchBuyers();
  }

  Future<void> _fetchBuyers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      myEmail = prefs.getString('email') ?? '';
      if (myEmail.isEmpty) {
        throw Exception('Email not found');
      }

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('http://192.168.1.77:3000/api/buyers'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          buyers = List<Map<String, dynamic>>.from(data['buyers']);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch buyers');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching buyers: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chats')),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : ListView.builder(
                itemCount: buyers.length,
                itemBuilder: (context, index) {
                  final buyer = buyers[index];
                  return ListTile(
                    title: Text(buyer['email']!),
                    subtitle: Text("subtitle" /*buyer['lastMessage']!*/),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ChatPage(
                                myEmail: myEmail,
                                peerEmail: buyer['email' /*id'*/]!,
                              ),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
