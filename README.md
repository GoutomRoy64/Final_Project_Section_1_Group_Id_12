# ClassTrack – Class Management & Attendance App

ClassTrack is a comprehensive mobile application built with **Flutter** and **Firebase**, designed to help teachers manage their courses, students, weekly routines, and attendance efficiently.

The app features a robust **Multi-Tenant Architecture** ensuring complete data privacy for every teacher, along with a **strict, time-bound Attendance System** to maintain accurate and tamper-proof records.

---

## 🚀 Key Features

### 🔐 Secure Authentication

* **Sign Up & Login**: Secure email/password authentication using Firebase Authentication.
* **Data Isolation**: Each teacher has a private workspace. Teacher A cannot view Teacher B’s courses or students.

### 📚 Course & Student Management

* **Manage Courses**: Add, edit, and delete courses (e.g., *Physics 101*).
* **Manage Students**: Enroll students into specific courses with Roll Numbers or Student IDs.

### 📅 Smart Scheduling (Routine)

* **Weekly Routine**: Schedule classes for specific days and time slots.
* **Dashboard Integration**: The Home Screen automatically highlights classes scheduled for **Today**.

### ✅ Advanced Attendance System

* **Strict Time Window**: Attendance can only be taken during the scheduled class time with an additional **5-minute buffer**.
* **Two-Phase Submission**:

    * **Step 1 – Roll Call**: Mark students as *Present* or *Absent*.
    * **Step 2 – Late Marking**: Update *Absent* students to *Late*. *Present* students are locked to prevent tampering.
* **Status Locking**: Once *Late Attendance* is saved, the record is permanently locked.

### 📊 Reports & Analytics

* **Real-time Statistics**: View total classes, present count, late count, and attendance .
* **Visual Indicators**:

    * 🟢 Green – Present
    * 🔴 Red – Absent
    * 🟠 Orange – Late

---

## 🛠️ Tech Stack

* **Frontend**: Flutter (Dart)
* **Backend**: Firebase Console (Authentication & Cloud Firestore)
* **State Management**: Provider Pattern
* **Architecture**: MVVM (Model–View–ViewModel)

---

## 📂 Project Structure

```text
lib/
├── models/           # Data definitions (Course, Student, Routine, Attendance)
├── providers/        # Business logic & Firebase interactions
├── screens/          # UI Screens
│   ├── auth/         # Login & Signup screens
│   ├── courses/      # Course management
│   ├── students/     # Student list & add screens
│   ├── routine/      # Schedule management
│   ├── attendance/   # Take Attendance & Summary screens
│   └── home_screen.dart
└── main.dart         # App entry point & Provider registration
```

---

## ⚙️ Installation & Setup

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/GoutomRoy64/Final_Project_Section_1_Group_Id_12.git
cd classtrack
```

### 2️⃣ Install Dependencies

```bash
flutter pub get
```

### 3️⃣ Firebase Configuration

1. Create a project in the **Firebase Console**.
2. Enable **Authentication** (Email/Password).
3. Enable **Cloud Firestore** (Test mode or secure mode).
4. Add your Android/iOS app to the Firebase project.
5. Download `google-services.json` (for Android) and place it in `android/app/`.

**OR**

Use FlutterFire CLI:

```bash
flutterfire configure
```

This will generate `lib/firebase_options.dart` automatically.

### 4️⃣ Run the App

```bash
flutter run
```

---

## 📖 How to Use

1. **Sign Up**: Create a new teacher account.
2. **Create Course**: Go to *Manage Courses* and add a subject (e.g., *Math*).
3. **Add Students**: Open a course and add students (e.g., *John Doe*).
4. **Set Routine**: Go to *Weekly Routine* and schedule the class for **today** at the current time.
5. **Take Attendance**:

    * Wait for the class time.
    * Open *Take Attendance*.
    * Mark students and click **Save Attendance**.
    * If a student arrives late, re-open and click **Save Late Attendance**.
6. **View Reports**: Tap the chart icon in the top-right corner to view the attendance sheet.