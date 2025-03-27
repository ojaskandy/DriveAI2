# DriveAI Lane Detection

This project contains two parts:
1. A Flutter app that shows a camera feed in the top half of the screen
2. A Python web server that performs lane detection using OpenCV

## Flutter App

The Flutter app is a simple camera application that shows the camera feed in the top half of the screen. It doesn't perform any lane detection.

### Running the Flutter App

To run the Flutter app, use the following command:

```bash
cd driveai2
flutter run
```

## Python Web Server

The Python web server uses OpenCV to perform lane detection on the camera feed. It provides a web interface where you can see the original camera feed and the processed feed with lane detection.

### Local Setup

1. Install the required Python packages:

```bash
cd driveai2
pip install -r requirements.txt
```

2. Run the web server:

```bash
cd driveai2
python web_server.py
```

3. Open your browser and navigate to http://localhost:8080

4. Click the "Start" button to start the camera feed and lane detection

5. Click the "Stop" button to stop the camera feed and lane detection

## Deploying to Render

This project is configured to be deployed to Render. Follow these steps to deploy:

1. Create a new Web Service on Render:

   - Sign in to your Render account
   - Click "New" and select "Web Service"
   - Connect your GitHub repository (https://github.com/ojaskandy/DriveAI2.git)
   - Use the following settings:
     - **Name**: DriveAI-Lane-Detection (or any name you prefer)
     - **Environment**: Python 3
     - **Region**: Choose the region closest to your users
     - **Branch**: main
     - **Build Command**: `pip install -r requirements.txt`
     - **Start Command**: `gunicorn web_server:app`
   - Click "Create Web Service"

2. Render will automatically deploy your application. Once deployed, you can access it at the URL provided by Render.

### Deployment Configuration

The following files are used for deployment:

- **requirements.txt**: Lists the Python dependencies
- **runtime.txt**: Specifies the Python version (3.9.16)
- **Procfile**: Tells Render how to run the application using Gunicorn
- **web_server.py**: The main application file, configured to work with Gunicorn

### Using the Deployed Application

1. Open the URL provided by Render in your web browser
2. Click the "Start" button to start your camera
3. The application will process the camera feed and display lane detection results
4. Click the "Stop" button to stop the camera feed

## Lane Detection Algorithm

The lane detection algorithm uses the following steps:

1. Convert the image to grayscale
2. Apply Gaussian blur to reduce noise
3. Apply Canny edge detection to find edges
4. Define a region of interest (ROI) to focus on the road
5. Apply Hough transform to detect lines
6. Separate left and right lane lines based on slope
7. Average the lines to get a single line for each lane
8. Draw the lines on the image
9. Calculate lane information (curvature and vehicle position)

## Future Improvements

- Implement more advanced lane detection algorithms
- Add lane departure warning
- Add object detection for vehicles and pedestrians
- Improve performance for real-time processing
