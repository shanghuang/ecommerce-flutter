import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CheckoutPage extends StatefulWidget {
  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _shippingInfo = {
    'fullName': '',
    'address': '',
    'address2': '',
    'city': '',
    'state': '',
    'zip': '',
    'country': 'United States',
    'phone': '',
  };
  final _paymentInfo = {
    'cardNumber': '',
    'expiration': '',
    'cvv': '',
    'cardHolderName': '',
    'billingZip': '',
  };
  List<dynamic> cartItems = [];
  String error = '';
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetchCartItems();
  }

  Future<void> _fetchCartItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('http://192.168.1.77:3000/api/cart'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          cartItems = jsonDecode(response.body)['items'] ?? [];
        });
      } else {
        throw Exception('Failed to fetch cart items');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isProcessing = true;
      error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final email = prefs.getString('email');

      if (token == null || email == null) {
        throw Exception('Not authenticated');
      }

      // Calculate total amount
      final totalAmount = cartItems.fold(0.0, (total, item) {
        return total + (item['price'] * item['quantity']);
      });

      final response = await http.post(
        Uri.parse('http://192.168.1.77:3000/api/checkout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': email,
          'shippingInfo': _shippingInfo,
          'paymentInfo': _paymentInfo,
          'cartItems': cartItems,
          'totalAmount': totalAmount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Navigator.pushReplacementNamed(
          context,
          '/order-confirmation',
          arguments: data['orderId'],
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Checkout failed');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(error, style: TextStyle(color: Colors.red[700])),
                ),
              Text(
                'Shipping Information',
                style: Theme.of(context).textTheme.headlineMedium, //headline6,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Full Name'),
                onChanged: (value) => _shippingInfo['fullName'] = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(labelText: 'Address'),
                onChanged: (value) => _shippingInfo['address'] = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your address';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Address Line 2 (Optional)',
                ),
                onChanged: (value) => _shippingInfo['address2'] = value,
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'City'),
                      onChanged: (value) => _shippingInfo['city'] = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your city';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'State/Province'),
                      onChanged: (value) => _shippingInfo['state'] = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your state';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'ZIP/Postal Code'),
                      onChanged: (value) => _shippingInfo['zip'] = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your ZIP code';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _shippingInfo['country'],
                      decoration: InputDecoration(labelText: 'Country'),
                      items:
                          ['United States', 'Canada', 'United Kingdom'].map((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _shippingInfo['country'] = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                onChanged: (value) => _shippingInfo['phone'] = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              Text(
                'Payment Information',
                style: Theme.of(context).textTheme.headlineMedium, //.headline6,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Card Number'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _paymentInfo['cardNumber'] = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your card number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'Expiration Date'),
                      onChanged: (value) => _paymentInfo['expiration'] = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter expiration date';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(labelText: 'CVV'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _paymentInfo['cvv'] = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter CVV';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(labelText: 'Cardholder Name'),
                onChanged: (value) => _paymentInfo['cardHolderName'] = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter cardholder name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(labelText: 'Billing ZIP Code'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _paymentInfo['billingZip'] = value,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter billing ZIP code';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              Text(
                'Order Summary',
                style:
                    Theme.of(context).textTheme.headlineMedium, // .headline6,
              ),
              SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Add cart items here
                    Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '\$99.99', // Replace with actual total
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isProcessing ? null : _submitOrder,
                  child:
                      isProcessing
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text('Place Order'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
