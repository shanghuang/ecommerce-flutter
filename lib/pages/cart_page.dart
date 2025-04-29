import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CartPage extends StatefulWidget {
  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<dynamic> cartItems = [];
  double total = 0.0;
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _fetchCartData();
  }

  Future<void> _fetchCartData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.get(
        Uri.parse('http://192.168.1.77:3000/api/cart'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          cartItems = data['items'] ?? [];
          _calculateTotal();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch cart data');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _calculateTotal() {
    double calculatedTotal = cartItems.fold(0.0, (sum, item) {
      return sum + (item['price'] * item['quantity']);
    });
    setState(() {
      total = calculatedTotal;
    });
  }

  Future<void> _updateQuantity(String itemId, int newQuantity) async {
    if (newQuantity < 1) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('http://192.168.1.77:3000/api/cart/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'itemId': itemId, 'quantity': newQuantity}),
      );

      if (response.statusCode == 200) {
        setState(() {
          cartItems =
              cartItems.map((item) {
                if (item['id'] == itemId) {
                  return {...item, 'quantity': newQuantity};
                }
                return item;
              }).toList();
          _calculateTotal();
        });
      } else {
        throw Exception('Failed to update cart');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  Future<void> _removeItem(String itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('http://192.168.1.77:3000/api/cart/remove'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'itemId': itemId}),
      );

      if (response.statusCode == 200) {
        setState(() {
          cartItems.removeWhere((item) => item['id'] == itemId);
          _calculateTotal();
        });
      } else {
        throw Exception('Failed to remove item');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.yourCart)),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Your Cart')),
        body: Center(child: Text(error, style: TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.yourCart)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (cartItems.isEmpty)
              Center(child: Text(AppLocalizations.of(context)!.yourCartIsEmpty))
            else ...[
              Expanded(
                child: ListView.builder(
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16.0),
                        title: Text(item['name']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('\$${item['price'].toStringAsFixed(2)}'),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove),
                                  onPressed:
                                      () => _updateQuantity(
                                        item['id'],
                                        item['quantity'] - 1,
                                      ),
                                ),
                                Text(item['quantity'].toString()),
                                IconButton(
                                  icon: Icon(Icons.add),
                                  onPressed:
                                      () => _updateQuantity(
                                        item['id'],
                                        item['quantity'] + 1,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeItem(item['id']),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${AppLocalizations.of(context)!.total}:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to checkout page
                    Navigator.pushNamed(context, '/checkout');
                  },
                  child: Text(AppLocalizations.of(context)!.proceedToCheckout),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/products');
              },
              child: Text(AppLocalizations.of(context)!.continueShopping),
            ),
          ],
        ),
      ),
    );
  }
}
