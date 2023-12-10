import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  late Dio _dio;

  ApiService() {
    BaseOptions options = BaseOptions(
      baseUrl: 'http://fedusu-test.deltateach.com/',
      connectTimeout: 5000,
      receiveTimeout: 3000,
    );

    _dio = Dio(options);

    // Optional: Add interceptors, authentication, etc.
    // _dio.interceptors.add(LogInterceptor(responseBody: true));
  }

  Future<void> _saveUserData(String userId, String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('userId', userId);
    prefs.setString('token', token);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      Response response = await _dio.post(
        'login',
        data: {
          'Username': username,
          'Password': password,
        },
      );

      Map<String, dynamic> responseData = response.data;

      // Save user data to SharedPreferences
      _saveUserData(responseData['userId'], responseData['token']);

      return responseData;
    } catch (error) {
      print('Failed to login: $error');
      throw Exception('Failed to login');
    }
  }

  // You can add other API methods here

  Future<String?> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }


}
