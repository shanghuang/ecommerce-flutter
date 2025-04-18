import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ProviderChatPage extends StatefulWidget {
  @override
  _ProviderChatPageState createState() => _ProviderChatPageState();
}

class _ProviderChatPageState extends State<ProviderChatPage> {
  String? selectedBuyer;
  List<Map<String, dynamic>> messages = [];
  List<dynamic> buyers = [];
  bool isLoadingMore = false;
  bool hasMoreMessages = true;
  late IO.Socket socket;
  final ScrollController _scrollController = ScrollController();
  String latestMessageId = '';
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSocket();
    _fetchBuyers();
    _scrollController.addListener(_onScroll);
  }

  void _initSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final userId = prefs.getString('userId');

    socket = IO.io('http://192.168.1.77:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      socket.emit('registerUser', {
        'email': email,
        'role': 'Provider',
        'userId': userId,
      });
    });

    socket.on('new_message', (message) {
      if (message['messageId'] != latestMessageId) {
        setState(() {
          messages.add({
            'sender': message['email'],
            'content': message['message'],
            'timestamp': DateTime.now(),
          });
          latestMessageId = message['messageId'];
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _fetchBuyers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

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
          buyers = data['buyers'];
        });
      } else {
        throw Exception('Failed to fetch buyers');
      }
    } catch (e) {
      print('Error fetching buyers: $e');
    }
  }

  Future<void> _selectBuyer(String buyerEmail) async {
    setState(() {
      selectedBuyer = buyerEmail;
      messages = [];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse(
          'http://192.168.1.77:3000/api/messages?buyerEmail=$buyerEmail',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          messages = List<Map<String, dynamic>>.from(data['messages']);
        });
        _scrollToBottom();
      } else {
        throw Exception('Failed to fetch messages');
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  Future<void> _loadMoreMessages() async {
    if (isLoadingMore ||
        !hasMoreMessages ||
        selectedBuyer == null ||
        messages.isEmpty)
      return;

    setState(() {
      isLoadingMore = true;
    });

    try {
      final oldestTimestamp = messages.first['timestamp'];
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse(
          'http://192.168.1.77:3000/api/messages?buyerEmail=$selectedBuyer&before=$oldestTimestamp',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          messages.insertAll(
            0,
            List<Map<String, dynamic>>.from(data['messages']),
          );
          hasMoreMessages = data['messages'].length > 0;
        });
      } else {
        throw Exception('Failed to load more messages');
      }
    } catch (e) {
      print('Error loading more messages: $e');
    } finally {
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.minScrollExtent) {
      _loadMoreMessages();
    }
  }

  void _sendMessage(String content) {
    if (selectedBuyer == null || content.trim().isEmpty) return;

    socket.emit('send_message', {
      'productId': 'all',
      'receiver': selectedBuyer,
      'message': content,
    });

    setState(() {
      messages.add({
        'sender': 'You',
        'content': content,
        'timestamp': DateTime.now(),
      });
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    socket.dispose();
    _scrollController.dispose();
    _messageController.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Buyer List
          Container(
            width: 300,
            color: Colors.grey[800],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Buyers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: buyers.length,
                    itemBuilder: (context, index) {
                      final buyer = buyers[index];
                      return ListTile(
                        title: Text(
                          buyer['email'],
                          style: TextStyle(color: Colors.white),
                        ),
                        tileColor:
                            selectedBuyer == buyer['email']
                                ? Colors.blue
                                : null,
                        onTap: () => _selectBuyer(buyer['email']),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Chat Window
          Expanded(
            child: Column(
              children: [
                AppBar(
                  title: Text(
                    selectedBuyer != null
                        ? 'Chat with $selectedBuyer'
                        : 'Select a buyer',
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: messages.length + (isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (isLoadingMore && index == 0) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final message =
                          messages[isLoadingMore ? index - 1 : index];
                      final isMe = message['sender'] == 'You';

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                message['content'],
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'HH:mm',
                                ).format(DateTime.parse(message['timestamp'])),
                                style: TextStyle(
                                  color: isMe ? Colors.white70 : Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (selectedBuyer != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController, // Add

                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.0),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                            ),
                            onSubmitted: (value) {
                              _sendMessage(value);
                              _messageController.clear(); // Clear the input
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.send),
                          onPressed: () {
                            _sendMessage(_messageController.text);
                            _messageController.clear();
                            ;
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
