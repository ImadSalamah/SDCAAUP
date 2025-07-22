// Helper to count graded cases for a student in a specific course from a cases map
int countGradedCasesForStudentInCourse(Map casesMap, String studentId, String courseId) {
  int count = 0;
  casesMap.forEach((caseKey, caseData) {
    if (caseData is Map &&
        caseData['studentId'] == studentId &&
        caseData['courseId'] == courseId &&
        caseData['status'] == 'graded') {
      count++;
    }
  });
  return count;
}
