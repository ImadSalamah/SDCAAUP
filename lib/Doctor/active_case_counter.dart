// Helper to count all cases (pending or graded) for a student in a specific course from a cases map
int countActiveCasesForStudentInCourse(Map casesMap, String studentId, String courseId) {
  int count = 0;
  casesMap.forEach((caseKey, caseData) {
    if (caseData is Map &&
        caseData['studentId'] == studentId &&
        caseData['courseId'] == courseId &&
        (caseData['status'] == 'graded' || caseData['status'] == 'pending')) {
      count++;
    }
  });
  return count;
}
