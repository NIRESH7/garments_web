# Production-Ready Mobile Backend (Node.js/Express/MongoDB)

This backend is designed specifically for mobile applications (Flutter/React Native) with a modular architecture and dedicated APIs for each mobile screen.

## 🚀 Getting Started

### Prerequisites
- Node.js (v18+)
- MongoDB (Local or Atlas)

### Setup
1. `cd mobile-backend`
2. `npm install`
3. Update `.env` with your MongoDB URI and JWT Secret.
4. `npm run dev`

---

## 📱 Screen-to-API Mapping

Each screen in your mobile app has a corresponding API endpoint:

| Mobile Screen | API Endpoint | Method | Module |
| :--- | :--- | :--- | :--- |
| **Splash** | `/api/home/splash` | GET | Home |
| **Login** | `/api/auth/login` | POST | Auth |
| **Register** | `/api/auth/register` | POST | Auth |
| **OTP Verification** | `/api/auth/verify-otp` | POST | Auth |
| **Forgot Password** | `/api/auth/forgot-password` | POST | Auth |
| **Home Dashboard** | `/api/home` | GET | Home |
| **Product List** | `/api/products` | GET | Product |
| **Product Detail** | `/api/products/:id` | GET | Product |
| **Cart** | `/api/cart` | GET/POST | Cart |
| **Profile** | `/api/users/profile` | GET | User |
| **Settings** | `/api/users/profile` | PUT | User |
| **Checkout** | `/api/orders` | POST | Order |
| **Payment** | `/api/payments/:id/pay` | PUT | Payment |
| **Orders List** | `/api/orders/myorders` | GET | Order |
| **Notifications** | `/api/notifications` | GET | Notification |
| **Support** | `/api/support` | POST | Support |
| **Categories Master** | `/api/master/categories` | POST/GET | Master |
| **Dropdown Setup** | `/api/master/categories/:id/values` | POST | Master |
| **Party Master** | `/api/master/parties` | POST/GET | Master |
| **Item Group Master** | `/api/master/item-groups` | POST/GET | Master |
| **Lot Inward Entry** | `/api/inventory/inward` | POST/GET | Inventory |
| **Outward** | `/api/inventory/outward` | POST/GET | Inventory |
| **Item Assignment** | `/api/production/assignments` | POST | Production |
| **Item Assignments List** | `/api/production/assignments` | GET | Production |

---

## 📂 Folder Responsibilities

The project follows a **Modular Design** where each feature is self-contained.

- **`src/modules/`**: Contains the core logic grouped by feature.
    - `model.js`: Mongoose schema defining the data structure.
    - `controller.js`: Handles request logic, interacts with services/models, and sends responses.
    - `routes.js`: Defines the API endpoints and connects them to controllers.
    - `service.js`: (Optional) Business logic that can be shared across controllers.
- **`src/middleware/`**: Custom Express middleware (e.g., `authMiddleware.js` for JWT protection, `errorMiddleware.js`).
- **`src/config/`**: Configuration files (Database, Third-party service initializations).
- **`src/utils/`**: Helper functions (JWT generation, formatters).

---

## 📡 API Request/Response Format

### Standard Success Response
All responses are returned as JSON objects.
```json
{
  "_id": "...",
  "name": "John Doe",
  "token": "eyJhbG..."
}
```

### Standard Error Response
Handled by the `errorHandler` middleware.
```json
{
  "message": "Invalid email or password",
  "stack": "..." // Only in development mode
}
```

---

## 🤳 Mobile Consumption Strategy

### 1. Authentication (JWT)
The mobile app should store the `token` (returned during login/register) securely using:
- **Flutter**: `flutter_secure_storage`
- **React Native**: `react-native-keychain` or `EncryptedStorage`

### 2. API Client Setup
Use `Dio` (Flutter) or `Axios` (React Native) with an **Interceptor** to automatically attach the token to every request.

**Example (Flutter/Dio Interceptor):**
```dart
dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    final token = storage.read('token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }
));
```

### 3. Handling Optimistic UI
For screens like **Cart** or **Product Review**, update the local state immediately and sync with the API in the background to provide a snappy user experience.

### 4. Push Notifications
The backend includes a `Notification` module. For production, integrate this with **Firebase Cloud Messaging (FCM)** using `firebase-admin` to send real-time alerts when `isPaid` becomes true or an order is shipped.
