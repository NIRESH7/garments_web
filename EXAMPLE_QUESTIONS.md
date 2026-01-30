# Example Questions for Your School Database

Based on your `school_ai_system` database schema, here are example questions you can ask:

## 📚 Student Information

### Basic Queries
- "Show all students"
- "Total students"
- "Students in class 10"
- "10 A students"
- "Students in class 10 section A"
- "Show students with last name Nair"
- "Students named Deepak"
- "Female students in class 10"
- "Male students only"
- "Student ID 103 full details"
- "Zoe Nair which class"
- "Avni Gupta section"

### Advanced Queries
- "Students in class 10 A sorted by roll number"
- "All students with roll number above 3"
- "Students by gender distribution"
- "Class 10 students with their sections"

---

## 📊 Attendance Queries

### View Attendance
- "Show attendance for student 103"
- "Avni Gupta attendance"
- "Class 10 attendance summary"
- "Students with low attendance"
- "Highest present days"
- "Most absent students"
- "Attendance for class 10 A"
- "Total attendance records"
- "Today's present students"

### Update Attendance (Attendance Agent)
- "Mark student 103 as present today"
- "Mark student 103 as absent"
- "Mark all students in class 10 A as present"
- "Mark all students in class 6 as present today"
- "Mark these students absent: 1023, 1027, 1031"
- "Set class 7 attendance: 25 present, 5 absent"
- "Update today's attendance for class 10"

---

## 📝 Marks & Exams

### View Marks
- "Marks for student 103"
- "Aditya Kumar marks"
- "Class 10 A students marks"
- "10 A students student wise english marks"
- "Biology average marks"
- "Highest marks student"
- "Lowest marks"
- "Failed students"
- "Students above 79% in class 10 A"
- "Average marks by subject"
- "Subject wise highest marks"

### Subject-Specific
- "English marks for class 10 A"
- "Mathematics marks"
- "Physics average"
- "Chemistry marks for Aditya Kumar"
- "Hindi marks"
- "Computer Science marks"

### Exam-Specific
- "Mid Term Exam results"
- "Final Exam marks for class 10"
- "Unit Test 1 results"
- "Exam results for student 103"

---

## 💰 Fees Information

### View Fees
- "Total fees pending"
- "Students with fee due"
- "Highest fee due"
- "Avni Gupta fees"
- "Kavya Reddy fees pending"
- "Fee due students list"
- "Students who paid all fees"
- "Class 10 fee summary"

### Fee Analysis
- "Total fees collected"
- "Total pending fees"
- "Average fee per student"
- "Fee payment status"

---

## 🏆 Rankings

### View Rankings
- "Top 10 students"
- "Best student in overall class"
- "Class rankings"
- "Rank 1 students"
- "Top 5 students by marks"
- "Best student girls only"
- "Ranking for class 10"

---

## 📅 Leave Records

### View Leaves
- "Total leaves"
- "Medical leave students"
- "Sick Leave student lists"
- "Personal leave students"
- "Family Emergency leaves"
- "Main reasons for leaves"
- "Who's having most number of leaves"
- "Class wise leave counts"
- "9th class leave student names and reasons"
- "Avni Gupta leaves"
- "Leave types"

### Leave Analysis
- "Medical leave counts"
- "Sick leave count"
- "Class wise leave high leaves"
- "Students with most leaves"

### Update Leave Records (Leave Agent)
- "Update leave type to personal for student 1"
- "Change leave type to medical for student 5"
- "Set leave type to personal for student ID 1"
- "Update leave days to 3 for student 10"
- "Change leave days to 5 for Aarav Patel"
- "Set leave type to medical and days to 5 for student 10"
- "Update leave type to personal for student 1"
- "Change leave type for student 1 to personal"
- "Modify leave type to Sick Leave for student 2"

---

## 👨‍🏫 Teachers & Subjects

### Teachers
- "Total teachers"
- "Chemistry teacher"
- "Mathematics teacher name"
- "All teachers"
- "Teachers by subject"

### Subjects
- "Subject names"
- "All subjects"
- "Total subjects"
- "Subjects list"

---

## 📋 Exams

### Exam Information
- "All exams"
- "Exams for class 10"
- "Mid Term Exam details"
- "Final Exam for class 12"

---

## 🔍 Advanced Queries

### Combined Queries
- "Avni Gupta full records" (all data)
- "Class 10 A students with marks and attendance"
- "Students with fee due and low attendance"
- "Top students with their fees status"
- "Failed students with attendance"

### Statistical Queries
- "Average marks by class"
- "Attendance percentage by class"
- "Fee collection rate"
- "Leave rate by class"
- "Gender distribution"
- "Class distribution"

### Filtering
- "Above 79% students in 10 class A section"
- "Only girls above 79%"
- "Students with attendance above 90%"
- "Students with no fee due"

---

## 💬 Contextual Follow-ups

After asking about a specific student, you can ask follow-ups:
- "Which class she is" (after asking about a female student)
- "Her roll number"
- "Her attendance"
- "Her marks"
- "Her fees"
- "Which gender she is"

---

## 🎯 Attendance Agent Examples

When using the Attendance Agent, try:
- "Mark student 103 as present today"
- "Mark student 103 as absent"
- "Mark all students in class 10 A as present"
- "Mark all students in class 6 as present today"
- "Mark these students absent: 1, 2, 3"
- "Set class 7 attendance: 25 present, 5 absent"
- "Update today's attendance for class 10"
- "Mark Rahul from class 5 as present today" (if student exists)

---

## 📊 Dashboard-Style Queries

- "Total students"
- "Total leaves"
- "Total fees pending"
- "Today's attendance"
- "Top 10 students"
- "Students with fee due"
- "Low attendance students"

---

## 💡 Tips

1. **Use natural language** - The AI understands questions like "who is the best student" or "show me students with low attendance"

2. **Follow-up questions** - After asking about a student, you can use pronouns like "she", "he", "her", "his" in follow-up questions

3. **Class and section** - You can specify class and section like "10 A", "class 10 section A", or "10th class A section"

4. **Attendance updates** - Use phrases like "mark as present", "mark as absent", "update attendance" to trigger the Attendance Agent

5. **Combined queries** - Ask for multiple pieces of information like "Avni Gupta full records" to get all data about a student

