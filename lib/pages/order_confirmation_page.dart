import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OrderConfirmationPage extends StatefulWidget {
  final String orderId;

  OrderConfirmationPage({required this.orderId});

  @override
  _OrderConfirmationPageState createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  Map<String, dynamic>? order;
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _fetchOrder();
  }

  Future<void> _fetchOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('http://192.168.1.77:3000/api/orders/${widget.orderId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          order = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch order');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Order Confirmation')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Order Confirmation')),
        body: Center(child: Text(error, style: TextStyle(color: Colors.red))),
      );
    }

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Order Confirmation')),
        body: Center(child: Text('Order not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Order Confirmation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[100],
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Thank you! Your order #${order!['id']} has been successfully placed.',
                style: TextStyle(color: Colors.green[700], fontSize: 16),
              ),
            ),
            SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Order Status: ${order!['status']}'),
                      Text(
                        'Order Total: \$${order!['total'].toStringAsFixed(2)}',
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Items Ordered',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Column(
                        children:
                            (order!['items'] as List).map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${item['name']} (x${item['quantity']})',
                                    ),
                                    Text(
                                      '\$${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shipping Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(order!['shippingInfo']['fullName']),
                      Text(order!['shippingInfo']['address']),
                      Text(
                        '${order!['shippingInfo']['city']}, '
                        '${order!['shippingInfo']['state']} '
                        '${order!['shippingInfo']['zip']}',
                      ),
                      Text(order!['shippingInfo']['country']),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
