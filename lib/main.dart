import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:convert';
import 'pages/login_page.dart'; // Add this import
import 'pages/registration_page.dart';
import 'pages/add_product_page.dart';
import 'pages/product_detail_page.dart';
import 'pages/cart_page.dart';
import 'pages/checkout_page.dart';
import 'pages/account/order_history_page.dart';
import 'pages/account/account_product_page.dart';
import 'pages/order_confirmation_page.dart';
//import 'pages/provider_chat_page.dart';
import 'pages/chat_list_page.dart';
//import 'l10n/l10n.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('en'), Locale('zh'), Locale('ja')],

      locale: Locale("zh"),
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: HomePage(),
      routes: {
        //'/': (context) => HomePage(),
        '/home': (context) => HomePage(),
        '/login': (context) => LoginPage(),
        '/registration': (context) => RegistrationPage(),
        '/add-product': (context) => AddProductPage(),
        '/cart': (context) => CartPage(),
        '/checkout': (context) => CheckoutPage(),
        '/order-history': (context) => OrderHistoryPage(),
        '/account-product': (context) => AccountProductsPage(),
        '/provider/chat': (context) => ChatListPage(),
        '/products':
            (context) => ProductDetailPage(
              productId: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/order-confirmation':
            (context) => OrderConfirmationPage(
              orderId: ModalRoute.of(context)!.settings.arguments as String,
            ),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> featuredProducts = [];
  bool isLoading = true;
  String error = '';
  String? userEmail;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _fetchFeaturedProducts();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final email = prefs.getString('email');

      if (token == null || email == null) {
        throw Exception('Not authenticated');
      }

      // Verify token validity with backend
      final response = await http.get(
        Uri.parse('http://192.168.1.77:3000/api/auth/verify'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          userEmail = email;
          isLoading = false;
        });
      } else {
        throw Exception('Invalid token');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _fetchFeaturedProducts() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.77:3000/api/products/featured'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          featuredProducts = data['products'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load featured products');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void logout() async {
    showDialog(
        context: context,
        builder: (BuildContext context)
    {
      return
        AlertDialog(
          title: const Text('Logout ?'),
          content: const SingleChildScrollView(
            child: ListBody(children: <Widget>[Text('Logout ?')]),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Yes'),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('jwt_token');
                final response = await http.post(
                  Uri.parse('http://192.168.1.77:3000/api/auth/logout'),
                  headers: {'Authorization': 'Bearer $token'},
                );
                if (response.statusCode == 200) {
                  prefs.remove('jwt_token');
                  prefs.remove('email');
                  print('Logout successful');
                  Navigator.pushNamed(context, '/');
                } else {
                  // Handle logout error
                  print('Logout failed: ${response.body}');
                }
                //Navigator.of(context).pop();
              },
            ),
          ],
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(AppLocalizations.of(context)!.helloWorld),
            if (userEmail != null) ...[
              SizedBox(width: 8),
              Text(
                '($userEmail)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              ),
            ],
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'login') {
                Navigator.pushNamed(context, '/login');
              } else if (value == 'add product') {
                Navigator.pushNamed(context, '/add-product');
              } else if (value == 'cart') {
                Navigator.pushNamed(context, '/cart');
              } else if (value == 'order') {
                Navigator.pushNamed(context, '/order-history');
              } else if (value == 'products') {
                Navigator.pushNamed(context, '/account-product');
              } else if (value == 'providerchat') {
                Navigator.pushNamed(context, '/provider/chat');
              } else if (value == 'logout') {
                logout();
              }
            },
            itemBuilder: (BuildContext context) {
              String loginOrOut = userEmail != null ? 'Logout' : 'Login';
              return {
                loginOrOut,
                'Add Product',
                'Cart',
                'Order',
                'Products',
                'ProviderChat',
              }.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice.toLowerCase(),
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : error.isNotEmpty
              ? Center(child: Text('Error: $error'))
              : featuredProducts.isEmpty
              ? Center(child: Text('No featured products available'))
              : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: featuredProducts.length,
                itemBuilder: (context, index) {
                  final product = featuredProducts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16.0),
                      //todo:
                      /*leading:
                          product['imageUrl'] != null
                              ? Image.network(
                                product['imageUrl'],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              )
                              : Icon(Icons.shopping_bag, size: 60),*/
                      title: Text(product['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product['description']),
                          SizedBox(height: 4),
                          Text(
                            '\$${product['price'].toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        // Navigate to product detail page
                        Navigator.pushNamed(
                          context,
                          '/products',
                          arguments: product['id'],
                        );
                      },
                    ),
                  );
                },
              ),
    );
  }
}
