// Returns true if the student has any pending case in the given course
bool hasPendingCaseForStudentInCourse(Map casesMap, String studentId, String courseId) {
  for (final caseData in casesMap.values) {
    if (caseData is Map &&
        caseData['studentId'] == studentId &&
        caseData['courseId'] == courseId &&
        caseData['status'] == 'pending') {
      return true;
    }
  }
  return false;
}
