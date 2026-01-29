# Garments Production App - User Guide & Documentation

## 📖 Introduction
This application is a comprehensive **inventory and production management tool** designed for garment manufacturing units. It helps track stock from inward entry to final dispatch, manages worker assignments, and provides real-time analytics—all stored securely on your device.

---

## 🚀 Getting Started

### 1. Login
*   **Secure Access:** The app launches with a login screen to prevent unauthorized access.
*   **Credentials:** Use your administrator credentials to enter the dashboard.

### 2. The Dashboard (Home)
The **Dashboard** is your command center. It gives you an instant snapshot of your factory's health.
*   **Inventory Overview:** at a glance, see:
    *   📦 **Total Lots:** Number of active lots in the system.
    *   ⚖️ **Stock Weight:** Total weight of raw material currently in stock.
    *   🚚 **Dispatched:** Total weight of items sent out.
    *   📋 **Assignments:** Active tasks assigned to workers.
*   **Recent Inwards:** A live feed showing the last 3 inward transactions with Lot Number, Party Name, and Weight.
*   **Navigation:** Use the **Bottom Menu Bar** to switch between modules:
    *   🏠 **Home:** Dashboard.
    *   🛢️ **Masters:** Setup data (Parties, Items, etc.).
    *   ↕️ **Transactions:** Record Inflow and Outflow (Center Button).
    *   📋 **Assessment:** Manage Assignments.
    *   📊 **Reports:** View detailed analytics.

---

## ⚙️ Masters (Setup)
*Found in the 2nd Tab (Database Icon)*

Before making transactions, set up your foundational data here.
1.  **Party Master:** Add suppliers, clients, and contractors (e.g., Knitting Unit, Dyeing House).
2.  **Item Master:** Define the types of items you handle (e.g., Fabric, Yarn).
3.  **Lot Master:** Create new production lots to track batches of goods.
4.  **Dropdown Setup:** Customize the options involved in your process, such as **Colors** (Red, Blue, Marl) and **Dia** (Diameter/Gauge).

---

## 🏭 Daily Operations (Transactions)
*Found in the Center Tab (Arrow Icon)*

This is where you record the physical movement of goods.

### 📥 Lot Inward (Adding Stock)
Use this when receiving new rolls or fabric.
*   **Select Context:** Choose the **Lot Number** and **From Party**.
*   **Entry Grid:**
    *   **Dia / Colour:** Select the properties of the fabric.
    *   **Roll:** Enter the roll count.
    *   **Weight (Kg):** enter the weight manually or use the **Scale Button** to capture from a connected device.
    *   **Add Multiple Rows:** You can add up to 11 different types of rolls in a single transaction.
*   **Save:** Confirms the stock and updates your inventory immediately.

### 📤 Lot Outward (Dispatching)
Use this when sending goods out (e.g., for processing or sales).
*   **Select Stock:** Choose which Lot and Items to dispatch.
*   **Quantity:** Specify the weight or quantity leaving the factory.

---

## 📋 Assessment (Assignments)
*Found in the 4th Tab (Clipboard Icon)*

Manage work orders and assignments.
*   **Assign Items:** Allocate specific stock items to a party (e.g., giving 50kg of yarn to a knitter).
*   **Track Status:** Monitor open assignments to ensure efficient workflow.

---

## 📊 Reports
*Found in the 5th Tab (Chart Icon)*

Gain insights into your business performance.
*   **Overview Report:** A high-level summary of total Inwards vs. Outwards.
*   **Monthly Summary:** Track performance month-over-month to spot trends.

---

## 🔒 Settings & Security
*   **Logout:** Tap the **Log Out** icon in the dashboard header to securely end your session.

---

## 🛠️ Technical Documentation (For Developers)

### Architecture
The app is built using **Flutter** and follows a modular, screen-based architecture.
*   **UI Framework:** Material Design with custom styling (`ColorPalette`).
*   **State Management:** `setState` (simple and efficient for this scope).
*   **Local Database:** `sqflite` (SQLite) is used for offline-first data storage.

### Folder Structure (`lib/`)
*   **`core/`**: Shared resources like `ColorPalette` (Theme).
*   **`models/`**: Data models representing database entities.
*   **`services/`**:
    *   `database_service.dart`: Manages SQLite creation, tables, and raw queries.
    *   `scale_service.dart`: Interface for external weighing scale hardware.
*   **`screens/`**:
    *   `auth/`: Login logic.
    *   `dashboard/`: Main home screen and navigation logic.
    *   `masters/`: CRUD screens for master data.
    *   `transactions/`: Logic for Inward/Outward flows.
    *   `assessment/`: Assignment tracking.
    *   `reports/`: Analytics visualizations.

### Database Schema (Key Tables)
*   `lots`: Stores Lot details.
*   `parties`: Stores Vendor/Client details.
*   `items`: Stores Item types.
*   `inwards` & `inward_rows`: Stores inward transactions and their specific line items (rolls/weights).
*   `outwards` & `outward_items`: Stores dispatch records.
*   `dropdowns`: Stores configurable options (Colors, Dias).

### Key Dependencies
*   `sqflite`: Database.
*   `curved_navigation_bar`: The bottom navigation UI.
*   `lucide_icons`: Icon pack.
*   `flutter_animate`: UI Animations.
