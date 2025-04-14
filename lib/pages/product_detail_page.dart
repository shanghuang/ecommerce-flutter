import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;

  ProductDetailPage({required this.productId});

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Map<String, dynamic>? product;
  bool isLoading = true;
  String error = '';
  bool isAddingToCart = false;
  String? cartMessage;
  bool isMessageSuccess = false;
  late final String? productId =
      ModalRoute.of(context)?.settings.arguments as String?;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  Future<void> _fetchProduct() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.77:3000/api/products/${widget.productId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          product = data['product'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch product');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _addToCart() async {
    if (product == null) return;

    setState(() {
      isAddingToCart = true;
      cartMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final userId = prefs.getString('userId');

      final response = await http.post(
        Uri.parse('http://192.168.1.77:3000/api/cart/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': userId,
          'productId': product!['id'],
          'quantity': 1,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          cartMessage = 'Product added to cart';
          isMessageSuccess = true;
        });
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to add product to cart',
        );
      }
    } catch (e) {
      setState(() {
        cartMessage = e.toString();
        isMessageSuccess = false;
      });
    } finally {
      setState(() {
        isAddingToCart = false;
      });

      // Clear message after 3 seconds
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            cartMessage = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Product Details')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Product Details')),
        body: Center(child: Text(error, style: TextStyle(color: Colors.red))),
      );
    }

    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Product Details')),
        body: Center(child: Text('Product not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Product Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cartMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isMessageSuccess ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cartMessage!,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            /*if (product!['imageUrl'] != null)
              Image.network(
                product!['imageUrl'],
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
              ),*/
            SizedBox(height: 16),
            Text(
              product!['name'],
              style: Theme.of(context).textTheme.headlineMedium, // .headline4,
            ),
            SizedBox(height: 8),
            if (product!['category'] != null)
              Text(
                'Category: ${product!['category']['name']}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            SizedBox(height: 16),
            Text(
              '\$${product!['price'].toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Description',
              style: Theme.of(context).textTheme.headlineMedium, //.headline6,
            ),
            SizedBox(height: 8),
            Text(
              product!['description'] ?? 'No description available',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Additional Information',
              style: Theme.of(context).textTheme.headlineMedium, //.headline6,
            ),
            SizedBox(height: 8),
            Text('Created: ${DateTime.parse(product!['createdAt']).toLocal()}'),
            Text('Updated: ${DateTime.parse(product!['updatedAt']).toLocal()}'),
            Text('Provider: ${product!['providerEmail']}'),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isAddingToCart ? null : _addToCart,
                child:
                    isAddingToCart
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Add to Cart'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            // Chat section can be added here
          ],
        ),
      ),
    );
  }
}
