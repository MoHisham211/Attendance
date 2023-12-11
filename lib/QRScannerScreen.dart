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
          // Successful response
          String jsonResponse = response.body;
          List<Course> courses = (json.decode(jsonResponse) as List)
              .map((courseJson) => Course.fromJson(courseJson))
              .toList();

          // Print the course data
          for (Course course in courses) {
            print('Course ID: ${course.courseId}, Name: ${course.courseName}');
          }

          // Save the courses to SharedPreferences
          final key = 'courses_key';

          prefs.setString(key, response.body);

          setState(() {
            data = courses;
            selectedValue = data.isNotEmpty ? data[0].courseName : '';
          });
        } else {
          // Error handling for non-200 status code
          print('Error: ${response.statusCode}');
          final snackBar=SnackBar(content: Text ('Error: ${response.statusCode}'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
      } catch (e) {
        // Error handling for network issues or exceptions
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
        // Handle the successful response here
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




/* Future<void> saveToExcel(String scannedData) async {
    List<String> excelData = scannedData.split(";");

    excelData.add(getCurrentDateTime());
    excelData.add(selectedValue);
    _sheet.appendRow(excelData);
    File file = File(_excelFilePath);
    var bytes = await _excel.encode();
    await file.writeAsBytes(bytes!);
    print('Scanned data appended to Excel: $_excelFilePath');
    /*_sheet.appendRow(excelData);
    File file = File(_excelFilePath);
    var bytes = await _excel.encode();
    await file.writeAsBytes(bytes!);
    print('Scanned data appended to Excel: $_excelFilePath');*/
  }*/

/*
  void saveAttendance() async {


    final String apiUrl = 'http://fedusu-test.deltateach.com/api/usercourses/SaveAttendance';

    // Replace 'YOUR_BEARER_TOKEN' with the actual Bearer token
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var userId = prefs.getString('userId');
    var token = prefs.getString('token');
    var courses_List=prefs.getString('courses_key');

    // Replace with your actual data
    final Map<String, dynamic> requestBody =
    {
      "UserId": "6d9ff0e1-cf89-47e0-a4eb-c8208c9e009a",
      "CourseId": "664",
      "AttendanceTitle": "Excel File Name",
      "StudentsAttendance": [
        {
          "StudentId": "189",
          "AttendanceTime": "1-1-2023 15:15:15",
        },
        {
          "StudentId": "479",
          "AttendanceTime": "1-1-2023 15:15:15",
        },
      ],
    };


    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      print('Success! Response: ${response.body}');
      // Handle the successful response here
    } else {
      print('Failed! Status Code: ${response.statusCode}, Body: ${response.body}');
      // Handle the error response here
    }
  }*/

/*@override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(
          'الماسح الضوئي',
          style: TextStyle(color: Colors.white),
            textDirection: TextDirection.rtl
            ,textAlign: TextAlign.right,
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
          crossAxisAlignment: CrossAxisAlignment.center, // Align content in the center horizontally
          children: <Widget>[
            ElevatedButton(
              onPressed: () => scanQR(),
              child: const Text('انقر لفحص رمز الاستجابة',

                style: const TextStyle(color: Color(0xFF2c3e52),)
                ,textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,),

            ),
            SizedBox(height: 20),
            Text('نتيجه الفحص:$_scanBarcode\n', style: const TextStyle(color: Color(0xFF2c3e52),fontSize: 20),
                textDirection: TextDirection.rtl
              ,textAlign: TextAlign.right,),
            Builder(
              builder: (context) {
                return DropdownButton<String>(
                  isExpanded: true,
                  value: selectedValue,
                  icon: Icon(Icons.arrow_downward
                  ,color: Color(0xFF2c3e52),),
                  iconSize: 24,
                  elevation: 16,
                  style: TextStyle(color: Color(0xFF2c3e52)),

                  // underline: Container(
                  //   height: 2,
                  //   color: Colors.deepPurpleAccent,
                  // ),
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
                          textDirection: TextDirection.rtl
                            ,textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }
            ),
          ],
        ),
      ),
    );
  }
}*/

 /*
  String _scanBarcode = '';
  late Excel _excel;
  late Sheet _sheet;
  String _excelFilePath = '';
  List<String> data = [];
  String selectedValue = 'Option 1'; // Default selected value

  @override
  void initState() {
    super.initState();
    initFilePath();
    initExcel();
    fetchData();
  }

  Future<void> initFilePath() async {
    String directory = (await getExternalStorageDirectory())!.path;
    _excelFilePath = '$directory/scanned_data.xlsx';
  }

  Future<void> initExcel() async {
    _excel = Excel.createExcel();
    _sheet = _excel['Sheet1'];

    if (!File(_excelFilePath).existsSync()) {
      _sheet.appendRow(['Scanned Data']);
    }
  }

  Future<void> fetchData() async {
    final apiUrl = 'http://fedusu-test.deltateach.com/api/UserCourses/Courses/';

    SharedPreferences prefs = await SharedPreferences.getInstance();
    var userId = prefs.getString('userId');
    var token = prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse('$apiUrl?userId=$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Successful response
        // Parse and display the data or handle it as needed

        String jsonResponse = response.body;
        List<Course> courses = (json.decode(jsonResponse) as List)
            .map((courseJson) => Course.fromJson(courseJson))
            .toList();

        // Process the course data
        for (Course course in courses) {
          data.add(course.courseName);
          print('Course ID: ${course.courseId}, Name: ${course.courseName}');
        }

        print(data);

        //final responseData = response.body;
        //Course course=Course.fromJson(response.body as Map<String, dynamic>);
        // Display the data in a toast message

        //print(responseData);
        //print(course.courseId);
      } else {
        // Error handling for non-200 status code
        print('${response.statusCode}');
      }
    } catch (e) {
      // Error handling for network issues or exceptions
      print('Error: $e');
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

  Future<void> saveToExcel(String scannedData) async {
    _sheet.appendRow([scannedData]);
    File file = File(_excelFilePath);
    var bytes = await _excel.encode();
    await file.writeAsBytes(bytes!);
    print('Scanned data appended to Excel: $_excelFilePath');
  }

  Future<void> logout() async {
    // Implement your logout logic here
    // For example, navigate to the login screen
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('userId');
    prefs.remove('token');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MyApp()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Barcode and QR code scan'),
          actions: [
            IconButton(
              icon: Icon(Icons.exit_to_app),
              onPressed: () => logout(),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => scanQR(),
                child: const Text('Start QR scan'),
              ),
              Text('Scan result : $_scanBarcode\n',
                  style: const TextStyle(fontSize: 20)),
              Text(
                selectedValue,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              DropdownButton<String>(
                value: selectedValue,
                icon: Icon(Icons.arrow_downward),
                iconSize: 24,
                elevation: 16,
                style: TextStyle(color: Colors.deepPurple),
                underline: Container(
                  height: 2,
                  color: Colors.deepPurpleAccent,
                ),
                //   onChanged: (String ? newValue) {
                //   setState(() {
                //     selectedValue = newValue!;
                //   });
                // },
                items:  data.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? value) {
                   setState(() {
                    selectedValue = value!;
                    });
                },//, onChanged: (String? value) {  },
              ),
            ],
          ),
        ),
      ),
    );
  }
  }*/



/*
*****WORK AND GET DATA FROM API
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


  @override
  void initState() {
    super.initState();
    initFilePath();
    initExcel();

    fetchData();
  }

  Future<void> initFilePath() async {
    String directory = (await getExternalStorageDirectory())!.path;
    _excelFilePath = '$directory/scanned_data.xlsx';
  }

  Future<void> initExcel() async {
    _excel = Excel.createExcel();
    _sheet = _excel['Sheet1'];

    if (!File(_excelFilePath).existsSync()) {
      _sheet.appendRow(['Scanned Data']);
    }
  }

  Future<void> fetchData() async {
    final apiUrl = 'http://fedusu-test.deltateach.com/api/UserCourses/Courses/';

    SharedPreferences prefs = await SharedPreferences.getInstance();
    var userId=prefs.getString('userId');
    var token =prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse('$apiUrl?userId=$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Successful response
        // Parse and display the data or handle it as needed
        final responseData = response.body;
        // Display the data in a toast message

        print(responseData);

      } else {
        // Error handling for non-200 status code
        print('${response.statusCode}');

      }
    } catch (e) {
      // Error handling for network issues or exceptions
      print('Error: $e');
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

  Future<void> saveToExcel(String scannedData) async {
    _sheet.appendRow([scannedData]);
    File file = File(_excelFilePath);
    var bytes = await _excel.encode();
    await file.writeAsBytes(bytes!);
    print('Scanned data appended to Excel: $_excelFilePath');
  }

  Future<void> logout() async {
    // Implement your logout logic here
    // For example, navigate to the login screen
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('userId');
    prefs.remove('token');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MyApp()),
      );

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Barcode and QR code scan'),
          actions: [
            IconButton(
              icon: Icon(Icons.exit_to_app),
              onPressed: () => logout(),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => scanQR(),
                child: const Text('Start QR scan'),
              ),
              Text('Scan result : $_scanBarcode\n',
                  style: const TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

*/

/*
-********************WORK ONE AND SAVE CSV*******************-
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  String _scanBarcode = '';

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
      // Save the scanned data to CSV
      saveToCsv(_scanBarcode);
    });
  }

  Future<void> saveToCsv(String scannedData) async {
    List<List<dynamic>> rows = [
      ['Scanned Data'],
      [scannedData],
    ];

    String csv = const ListToCsvConverter().convert(rows);

    String directory = (await getExternalStorageDirectory())!.path;
    String filePath = '$directory/scanned_data.csv';

    File file = File(filePath);
    await file.writeAsString(csv);

    print('Scanned data saved to: $filePath');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Barcode and QR code scan')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => scanQR(),
                child: const Text('Start QR scan'),
              ),
              Text('Scan result : $_scanBarcode\n',
                  style: const TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}*/



/*
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  String _scanBarcode = '';

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
      // Save the scanned data to Excel
      saveToExcel(_scanBarcode);
    });
  }

  Future<void> saveToExcel(String scannedData) async {
    var excel = Excel.createExcel();
    var sheet = excel['Sheet1'];

    // Add header row
    sheet.appendRow(['Scanned Data']);

    // Add scanned data row
    sheet.appendRow([scannedData]);

    // Get the directory for saving the Excel file
    String dir = (await getApplicationDocumentsDirectory()).path;

    // Save the Excel file
    var file = '$dir/example.xlsx';
    File('$dir/example.xlsx').
    writeAsBytesSync(file);
    print('Excel file saved at: $file');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Barcode and QR code scan')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => scanQR(),
                child: const Text('Start QR scan'),
              ),
              Text('Scan result : $_scanBarcode\n',
                  style: const TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}*/





/*import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';



class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<QRScannerScreen> {
  String _scanBarcode = '';


  Future<void> startBarcodeScanStream() async {
    FlutterBarcodeScanner.getBarcodeStreamReceiver(
        '#ff6666', 'Cancel', true, ScanMode.BARCODE)!
        .listen((barcode) => debugPrint(barcode));
  }

  Future<void> scanQR() async {
    String barcodeScanRes;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 'Cancel', true, ScanMode.QR);
      debugPrint(barcodeScanRes);
    } on PlatformException {
      barcodeScanRes = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _scanBarcode = barcodeScanRes;
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> scanBarcodeNormal() async {
    String barcodeScanRes;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 'Cancel', true, ScanMode.DEFAULT);
    } on PlatformException {
      barcodeScanRes = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _scanBarcode = barcodeScanRes;
      saveToExcel();
    });
  }

  Future<void> saveToExcel() async {
    var excel = Excel.createExcel();
    var sheet = excel['Sheet1'];

    // Add header row
    sheet.appendRow(['Name', 'Age', 'City']);

    // Add data rows
    sheet.appendRow(['John Doe', 30, 'New York']);
    sheet.appendRow(['Jane Doe', 25, 'Los Angeles']);
    sheet.appendRow(['Bob Smith', 40, 'Chicago']);

    // Get the directory for saving the Excel file
    String dir = (await getApplicationDocumentsDirectory()).path;

    // Save the Excel file
    var file = '$dir/example.xlsx';
    await excel.save(fileName: "$dir/example.xlsx");
    print("$dir/example.xlsx");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Barcode and QR code scan')),
        body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                OutlinedButton(
                    onPressed: () => scanBarcodeNormal(),
                    child: const Text('Start barcode scan')),
                OutlinedButton(
                    onPressed: () => scanQR(),
                    child: const Text('Start QR scan')),
                OutlinedButton(
                    onPressed: () => startBarcodeScanStream(),
                    child: const Text('Start barcode scan stream')),
                Text('Scan result : $_scanBarcode\n',
                    style: const TextStyle(fontSize: 20))
              ]
          ),
        ),
      ),
    );
  }


}*/
//import 'package:qr_code_scanner/qr_code_scanner.dart';
/*class QRScannerScreen extends StatefulWidget {
  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  late QRViewController controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Code Scanner'),
      ),
      body: _buildQrView(context),
    );
  }

  Widget _buildQrView(BuildContext context) {
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      // Handle the scanned data here
      print('Scanned data: $scanData');
      // You can use the data as needed
      // For example, display it in a dialog or navigate to a new screen
      _showDialog(scanData);
    });
  }

  void _showDialog(String data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('QR Code Scanned'),
          content: Text('Data: $data'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}*/
