import 'dart:convert';
import 'package:attendance/main.dart';
import 'package:attendance/model/Course.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;



class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {


  String _scanBarcode = '';
  late Excel _excel;
  late Sheet _sheet;
  String _excelFilePath = '';
  List<Course> data = [];
  String selectedValue = ''; // Default selected value
  Set<List<String>> uniqueRows = Set<List<String>>();
  Set<String> uniqueData = Set<String>();
  //String prepareUploading='';
  List<Map<String, dynamic>> studentsAttendance = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    initFilePath(getCurrentDateTime());
    initExcel();
    fetchData();
  }

  Future<void> initFilePath(String name) async {
    String directory = (await getExternalStorageDirectory())!.path;
    _excelFilePath = '$directory/$name-$selectedValue.xlsx';
  }

  Future<void> initExcel() async {
    _excel = Excel.createExcel();
    _sheet = _excel['Sheet1'];

    List<String> headers = ["الكود", "الاسم", "الفرقة", "التاريخ", "الماده"];
    _sheet.appendRow(headers);

    if (!File(_excelFilePath).existsSync()) {
      _sheet.appendRow(['نتيجة المسح']);
    }
  }

  Future<void> fetchData() async {
    final apiUrl = 'http://fedusu-test.deltateach.com/api/UserCourses/Courses/';

    SharedPreferences prefs = await SharedPreferences.getInstance();
    var userId = prefs.getString('userId');
    var token = prefs.getString('token');
    var courses_List=prefs.getString('courses_key');

    if(courses_List!=null)
      {

        List<Course> courses = (json.decode(courses_List) as List)
            .map((courseJson) => Course.fromJson(courseJson))
            .toList();

        setState(() {
          data = courses;
          selectedValue = data.isNotEmpty ? data[0].courseName : '';
        });

      }
    else {
      try {
        final response = await http.get(
          Uri.parse('$apiUrl?userId=$userId'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          String jsonResponse = response.body;
          List<Course> courses = (json.decode(jsonResponse) as List)
              .map((courseJson) => Course.fromJson(courseJson))
              .toList();

          for (Course course in courses) {
            print('Course ID: ${course.courseId}, Name: ${course.courseName}');
          }

          final key = 'courses_key';
          prefs.setString(key, response.body);
          setState(() {
            data = courses;
            selectedValue = data.isNotEmpty ? data[0].courseName : '';
          });
        } else {

          print('Error: ${response.statusCode}');
          final snackBar=SnackBar(content: Text ('Error: ${response.statusCode}'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
      } catch (e) {

        print('Error: $e');
        final snackBar=SnackBar(content: Text ('Error: $e'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }
    }
  }

  Future<void> scanQR() async {
    String barcodeScanRes;
    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Cancel',
        true,
        ScanMode.QR,
      );
      debugPrint(barcodeScanRes);
    } on PlatformException {
      barcodeScanRes = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _scanBarcode = barcodeScanRes;
      saveToExcel(_scanBarcode);
    });
  }


  Future<void> postAttendanceData() async {

    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    var userId = prefs.getString('userId');
    var token = prefs.getString('token');

    String courseId = data.isNotEmpty ? data[0].courseId.toString() : ''; // Set the appropriate way to get courseId from data

    print("CourseId="+courseId);
    print("Data"+studentsAttendance.toString());

    final String apiUrl = 'http://fedusu-test.deltateach.com/api/usercourses/SaveAttendance';

    // Replace 'YOUR_BEARER_TOKEN' with the actual Bearer token
    final Map<String, dynamic> requestBody = {
      'UserId': userId,
      'CourseId': courseId,
      'AttendanceTitle': (selectedValue+" : "+getCurrentDateTime()).toString(),
      'StudentsAttendance': studentsAttendance,
    };

    print("request"+requestBody.toString());
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json', // Specify content type
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        print('Success! Response: ${response.body}');

        Map<String, dynamic> parsedBody = json.decode(response.body);

        if (parsedBody['saved'] == true) {

          print('تم رفع الملف بنجاح');
          final snackBar=SnackBar(content: Text ('تم رفع الملف بنجاح'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        } else {
          print('يرجي العلم انه توجد بعض المشاكل في الملف');
          final snackBar=SnackBar(content: Text ('يرجي العلم انه توجد بعض المشاكل في الملف'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }

        setState(() {
          isLoading = false;
        });

      } else {
        print('Failed! Status Code: ${response.statusCode}, Body: ${response.body}');
        final snackBar=SnackBar(content: Text ('Failed! Status Code: ${response.statusCode}, Body: ${response.body}'));
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        // Handle the error response here
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      final snackBar=SnackBar(content: Text ('Error: $e'));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      // Handle network or other exceptions here
      setState(() {
        isLoading = false;
      });
    }

  }

  Future<void> saveToExcel(String scannedData) async {
    if (!uniqueData.contains(scannedData)) {
      // Add the current data to the set if it's not a duplicate
      uniqueData.add(scannedData);

      List<String> excelData = scannedData.split(";");

      excelData.add(getCurrentDateTime());
      excelData.add(selectedValue);

      studentsAttendance.add({
        'StudentId': excelData[0].toString(),
        'AttendanceTime': getCurrentDateTime().toString(),
      });

      // Append the row to the Excel sheet
      _sheet.appendRow(excelData);

      // Write changes to the file
      File file = File(_excelFilePath);
      var bytes = await _excel.encode();
      await file.writeAsBytes(bytes!);

      print('Scanned data appended to Excel: $_excelFilePath');
    } else {
      // Handle the case where the data is a duplicate
      final snackBar=SnackBar(content: Text ('يرجي العلم ان هذا الطالب تم تسجيله مسبقا'));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      print('Duplicate data found. Did not append to Excel.');
    }
  }


  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('userId');
    prefs.remove('token');
    prefs.remove('courses_key');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MyApp()),
    );
  }

  String getCurrentDateTime() {
    DateTime now = DateTime.now();
    String formattedDate = "${now.year}-${_addLeadingZero(
        now.month)}-${_addLeadingZero(now.day)} ${_addLeadingZero(
        now.hour)}:${_addLeadingZero(now.minute)}:${_addLeadingZero(
        now.second)}";

    return formattedDate;
  }

  String _addLeadingZero(int number) {
    return number.toString().padLeft(2, '0');
  }



  @override
  Widget build(BuildContext context) {

      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Color(0xFF2c3e52),
        appBar: AppBar(
          title: const Text(
            'الماسح الضوئي',
            style: TextStyle(color: Colors.white),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          backgroundColor: Color(0xFF2c3e52),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.exit_to_app),
              color: Colors.white,
              onPressed: () => logout(),
            ),
          ],
        ),
        body: Container(
          alignment: AlignmentDirectional.centerStart,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: () => scanQR(),
                child: const Text(
                  'انقر لفحص رمز الاستجابة',
                  style: const TextStyle(color: Color(0xFF2c3e52)),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'نتيجه الفحص:$_scanBarcode\n',
                style: const TextStyle(color: Color(0xffffffff), fontSize: 20),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
              ),
              Builder(
                builder: (context) {
                  return Container(
                    margin: EdgeInsets.all(8.0), // Adjust the margin as needed
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedValue,
                      icon: Icon(
                        Icons.arrow_downward,
                        color: Color(0xffffffff),
                      ),
                      iconSize: 24,
                      elevation: 16,
                      style: TextStyle(color: Colors.grey),
                      onChanged: (String? value) {
                        setState(() {
                          selectedValue = value!;
                        });
                      },
                      items: data.map<DropdownMenuItem<String>>((Course course) {
                        return DropdownMenuItem<String>(
                          value: course.courseName,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              course.courseName,
                              style: TextStyle(fontSize: 16),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              SizedBox(height: 20),
              // Progress bar
              if (isLoading)
                CircularProgressIndicator(),
              SizedBox(height: 20),
              Container(
                width: double.infinity,
                // Take up all available width
                height: 40,
                margin: EdgeInsets.symmetric(horizontal: 50),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Colors.green[900],
                ),
                child: InkWell(
                  onTap: () {
                    postAttendanceData();
                  },
                  child: Center(
                    child: Text(
                      "رفع الغياب",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    }
}