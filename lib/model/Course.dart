class Course {
  final int courseId;
  final String courseName;

  Course({required this.courseId, required this.courseName});

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(courseId: json['CourseId'], courseName: json['CourseName']);
  }

  // Map<String, dynamic> toJson() {
  //   return {
  //     'courseId': courseId,
  //     'courseName': courseName,
  //   };
  // }
}
