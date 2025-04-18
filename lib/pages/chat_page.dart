import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  final String peerEmail;
  final String myEmail;

  ChatPage({required this.peerEmail, required this.myEmail});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late IO.Socket socket;
  final List<Map<String, dynamic>> messages = [];
  final TextEditingController _messageController = TextEditingController();
  String latestMessageId = '';
  bool isLoadingMore = false;
  bool hasMoreMessages = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initSocket();
    _loadMoreMessages();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.minScrollExtent) {
      _loadMoreMessages();
    }
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

  void _initSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final userId = prefs.getString('userId');

    socket = IO.io('http://192.168.1.77:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      socket.emit(
        'register_user',
        jsonEncode({'email': email, 'username': 'Provider', 'userId': userId}),
      );
    });

    socket.on('receive_message', (message) {
      if (message['messageId'] != latestMessageId) {
        setState(() {
          messages.add({
            'receiverEmail': email,
            'senderEmail': message['email'],
            'content': message['message'],
            'timestamp': DateTime.parse(message['timestamp']),
          });
          latestMessageId = message['messageId'];
        });
      }
    });
  }

  void _sendMessage(String content) {
    if (content.trim().isEmpty) return;

    socket.emit(
      'send_message',
      jsonEncode({
        'productId': 'all',
        'receiverEmail': widget.peerEmail,
        'message': content,
      }),
    );

    setState(() {
      messages.add({
        'sender': 'You',
        'content': content,
        'timestamp': DateTime.now(),
      });
    });
    _messageController.clear();
  }

  Future<void> _loadMoreMessages() async {
    if (isLoadingMore ||
        !hasMoreMessages /*||
        messages.isEmpty*/ )
      return;

    setState(() {
      isLoadingMore = true;
    });

    try {
      //final oldestTimestamp = messages.first['timestamp'];
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      var timestampQuery = '';
      if (messages.isNotEmpty) {
        final oldestTimestamp = messages.first['timestamp'];
        timestampQuery = '&before=$oldestTimestamp';
      }
      final response = await http.get(
        Uri.parse(
          'http://192.168.1.77:3000/api/messages?buyerEmail=${widget.peerEmail}' +
              timestampQuery, //&before=$oldestTimestamp',
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

  @override
  void dispose() {
    _scrollController.dispose();
    socket.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat with ${widget.peerEmail}')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.all(16.0),
              itemCount: messages.length + (isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (isLoadingMore && index == messages.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final message = messages[messages.length - 1 - index];
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
                          DateFormat('HH:mm').format(
                            DateTime.parse(message['timestamp'].toString()),
                          ),
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      _sendMessage(value);
                      _scrollToBottom();
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    _sendMessage(_messageController.text);
                    _scrollToBottom();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
