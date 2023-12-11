import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ApiService.dart';
import 'QRScannerScreen.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  ApiService _apiService = ApiService();

  Future<void> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    String? token = prefs.getString('token');

    if (userId != null && token != null) {
      // User is logged in, navigate to another activity
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => QRScannerScreen()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> _login() async {
    try {
      setState(() {
        isLoading = true;
      });
      Map<String, dynamic> response = await _apiService.login(
        usernameController.text,
        passwordController.text,
      );
      final snackBar=SnackBar(content: Text ('مرحبا بك في برنامج تسجيل الحضور'));
      print(response);
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      setState(() {
        isLoading = false;
      });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => QRScannerScreen()),
      );
    } catch (error) {
      print(error);
      final snackBar=SnackBar(content: Text (error.toString()));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [
              Colors.green[900]!,
              Colors.green[800]!,
              Colors.green[400]!
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(height: 80,),
            Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  // Left image
                  Image.asset(
                    'images/leftlogo.jpeg',
                    width: 40,
                    height: 40,
                  ),
                  // Text
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        "تسجيل الدخول",
                        style: TextStyle(color: Colors.white, fontSize: 30),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 5,),
                      Text(
                        "مرحبًا بك في نظام الحضور لدينا",
                        style: TextStyle(color: Colors.white, fontSize: 20),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  // Right image
                  Image.asset(
                    'images/rightlogo.jpeg',
                    width: 40,
                    height: 40,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20,),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(60),
                    topRight: Radius.circular(60),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: 60,),
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green,
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey)),
                              ),
                              child: TextField(
                                controller: usernameController,
                                decoration: InputDecoration(
                                  hintText: "اسم المستخدم أو رقم الهاتف",
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                              ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey)),
                              ),
                              child: TextField(
                                controller: passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  hintText: "كلمة المرور",
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 40,),
                      // Progress bar
                      if (isLoading)
                        CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Container(
                        width: double.infinity, // Take up all available width
                        height: 50,
                        margin: EdgeInsets.symmetric(horizontal: 50),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          color: Colors.green[900],
                        ),
                        child: InkWell(
                          onTap: () {
                            _login();
                          },
                          child: Center(
                            child: Text(
                              "تسجيل الدخول",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
