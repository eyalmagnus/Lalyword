# How to Run Lalyword Web App on Another Computer

This guide explains how to run the built web app on a computer **without Flutter SDK** installed.

## What You Have

After building, you have a `lalyword-web-build.zip` file containing all the web app files. This is a **standalone** web application that can run in any modern web browser.

## Step 1: Transfer the Files

1. Copy `lalyword-web-build.zip` to the other computer (via USB drive, email, cloud storage, etc.)
2. Extract the zip file to a folder (e.g., `lalyword-web`)

## Step 2: Run a Local Web Server

**Important:** You cannot simply double-click `index.html` to open it in a browser due to browser security (CORS restrictions). You need to serve it via a local HTTP server.

### Option A: Python (Easiest - Works on Windows, Mac, Linux)

If Python is installed (most computers have it):

1. Open Terminal (Mac/Linux) or Command Prompt (Windows)
2. Navigate to the extracted folder:
   ```bash
   cd path/to/lalyword-web
   ```
3. Run the server:
   
   **Python 3:**
   ```bash
   python3 -m http.server 8000
   ```
   
   **Python 2 (if Python 3 not available):**
   ```bash
   python -m SimpleHTTPServer 8000
   ```

4. Open your browser and go to:
   ```
   http://localhost:8000
   ```

### Option B: Node.js (if installed)

If Node.js is installed:

1. Install a simple server globally:
   ```bash
   npm install -g http-server
   ```
2. Navigate to the extracted folder:
   ```bash
   cd path/to/lalyword-web
   ```
3. Run the server:
   ```bash
   http-server -p 8000
   ```
4. Open browser to `http://localhost:8000`

### Option C: PHP (if installed)

If PHP is installed:

1. Navigate to the extracted folder:
   ```bash
   cd path/to/lalyword-web
   ```
2. Run:
   ```bash
   php -S localhost:8000
   ```
3. Open browser to `http://localhost:8000`

### Option D: Use a Simple Web Server Application

Download and use a simple web server app:
- **Windows:** [HFS (HTTP File Server)](http://www.rejetto.com/hfs/)
- **Mac:** [MAMP](https://www.mamp.info/) or [XAMPP](https://www.apachefriends.org/)
- **Any:** [Live Server extension in VS Code](https://marketplace.visualstudio.com/items?itemName=ritwickdey.LiveServer)

## Step 3: Access the App

Once the server is running, open your web browser and navigate to:
```
http://localhost:8000
```

The app should load and work just like it does on your development machine!

## Troubleshooting

### Port Already in Use
If port 8000 is busy, use a different port:
- Python: `python3 -m http.server 8080`
- Node: `http-server -p 8080`
- PHP: `php -S localhost:8080`

Then access via `http://localhost:8080`

### Browser Won't Load
- Make sure the server is actually running (you should see activity in the terminal)
- Try a different browser (Chrome, Firefox, Edge, Safari)
- Clear browser cache
- Check browser console for errors (F12 → Console tab)

### Files Not Found Errors
- Make sure you extracted the entire `build/web` folder contents
- Don't open `index.html` directly - use the HTTP server!

## File Size

The built web app is approximately **30 MB** (mostly due to CanvasKit rendering engine). This is normal for Flutter web apps using CanvasKit renderer.

## Notes

- This is a **release build**, so it's optimized for performance
- Hot reload won't work (this is expected for built apps)
- The app runs entirely in the browser - no server-side code needed
- Works offline once loaded (if service worker is enabled)

