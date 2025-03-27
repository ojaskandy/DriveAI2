import os
import cv2
import numpy as np
from flask import Flask, Response, render_template, request, jsonify
from flask_cors import CORS
import base64
import time

app = Flask(__name__, static_folder='web', static_url_path='')
CORS(app)  # Enable CORS for all routes

# Global variables for lane detection
last_warped_image = None
last_lane_info = None

@app.route('/')
def index():
    return app.send_static_file('index.html')

@app.route('/process_frame', methods=['POST'])
def process_frame():
    global last_warped_image, last_lane_info
    
    try:
        # Get the image data from the request
        data = request.json
        image_data = data['image'].split(',')[1]
        
        # Decode the base64 image
        image_bytes = base64.b64decode(image_data)
        nparr = np.frombuffer(image_bytes, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        # Process the image with lane detection
        result_image, lane_info = process_image(image)
        
        # Encode the result image as base64
        _, buffer = cv2.imencode('.jpg', result_image)
        result_image_base64 = base64.b64encode(buffer).decode('utf-8')
        
        return jsonify({
            'image': f'data:image/jpeg;base64,{result_image_base64}',
            'lanes': lane_info
        })
    except Exception as e:
        print(f"Error processing frame: {e}")
        return jsonify({'error': str(e)}), 500

def process_image(image):
    global last_warped_image, last_lane_info
    
    try:
        # Resize image for better performance
        image = cv2.resize(image, (640, 480))
        
        # Apply simple lane detection (just for demonstration)
        # Convert to grayscale
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        
        # Apply Gaussian blur
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        
        # Apply Canny edge detection
        edges = cv2.Canny(blur, 50, 150)
        
        # Define region of interest
        mask = np.zeros_like(edges)
        height, width = image.shape[:2]
        polygon = np.array([
            [(0, height), (width, height), (width//2, height//2)]
        ], np.int32)
        cv2.fillPoly(mask, polygon, 255)
        masked_edges = cv2.bitwise_and(edges, mask)
        
        # Apply Hough transform to detect lines
        lines = cv2.HoughLinesP(masked_edges, 2, np.pi/180, 100, np.array([]), minLineLength=40, maxLineGap=5)
        
        # Create a blank image to draw lines on
        line_image = np.zeros((height, width, 3), dtype=np.uint8)
        
        # Variables to store lane lines
        left_lines = []
        right_lines = []
        
        if lines is not None:
            for line in lines:
                x1, y1, x2, y2 = line[0]
                # Calculate slope
                if x2 - x1 == 0:
                    continue  # Skip vertical lines
                slope = (y2 - y1) / (x2 - x1)
                
                # Filter lines based on slope
                if abs(slope) < 0.5:
                    continue  # Skip horizontal lines
                
                # Separate left and right lanes based on slope
                if slope < 0:
                    left_lines.append(line)
                else:
                    right_lines.append(line)
        
        # Function to average lines
        def average_lines(lines):
            if len(lines) == 0:
                return None
            
            x_coords = []
            y_coords = []
            
            for line in lines:
                x1, y1, x2, y2 = line[0]
                x_coords.extend([x1, x2])
                y_coords.extend([y1, y2])
            
            # Fit a line to the points
            if len(x_coords) > 0 and len(y_coords) > 0:
                z = np.polyfit(x_coords, y_coords, 1)
                slope = z[0]
                intercept = z[1]
                
                # Calculate endpoints
                y1 = height
                y2 = int(height * 0.6)
                x1 = int((y1 - intercept) / slope) if slope != 0 else 0
                x2 = int((y2 - intercept) / slope) if slope != 0 else 0
                
                return np.array([[x1, y1, x2, y2]])
            
            return None
        
        # Average the lines
        left_line = average_lines(left_lines)
        right_line = average_lines(right_lines)
        
        # Draw the lines on the image
        if left_line is not None:
            x1, y1, x2, y2 = left_line[0]
            cv2.line(line_image, (x1, y1), (x2, y2), (0, 0, 255), 5)
        
        if right_line is not None:
            x1, y1, x2, y2 = right_line[0]
            cv2.line(line_image, (x1, y1), (x2, y2), (0, 255, 0), 5)
        
        # Combine the original image with the line image
        result = cv2.addWeighted(image, 0.8, line_image, 1, 0)
        
        # Calculate lane info
        lane_info = {}
        
        if left_line is not None and right_line is not None:
            # Calculate curvature (simplified)
            left_curverad = 1000.0  # Placeholder value
            right_curverad = 1000.0  # Placeholder value
            
            # Calculate vehicle position
            left_x = left_line[0][0]
            right_x = right_line[0][0]
            lane_center = (left_x + right_x) / 2
            vehicle_center = width / 2
            deviation = (vehicle_center - lane_center) * 3.7 / width  # Convert to meters
            
            lane_info = {
                'left_fit': [0, 0, 0],  # Placeholder
                'right_fit': [0, 0, 0],  # Placeholder
                'left_curverad': float(left_curverad),
                'right_curverad': float(right_curverad),
                'deviation': float(deviation)
            }
            
            # Add text to the image
            cv2.putText(result, f'Radius of curvature: {round(left_curverad, 1)}m', (30, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
            direction = "left" if deviation < 0 else "right"
            cv2.putText(result, f'Vehicle is {round(abs(deviation), 3)}m {direction} of center', (30, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
        
        return result, lane_info
    except Exception as e:
        print(f"Error in process_image: {e}")
        # Return the original image if processing fails
        return image, {}

# Create the web directory if it doesn't exist
if not os.path.exists('web'):
    os.makedirs('web')

# Create a simple index.html file if it doesn't exist
if not os.path.exists('web/index.html'):
    with open('web/index.html', 'w') as f:
        f.write('''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DriveAI Lane Detection</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            text-align: center;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        .video-container {
            margin-top: 20px;
            position: relative;
        }
        video {
            width: 100%;
            border: 1px solid #ccc;
        }
        canvas {
            width: 100%;
            border: 1px solid #ccc;
        }
        .controls {
            margin-top: 20px;
        }
        button {
            padding: 10px 20px;
            margin: 0 10px;
            font-size: 16px;
            cursor: pointer;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>DriveAI Lane Detection</h1>
        <p>Real-time lane detection using OpenCV and Flask</p>
        
        <div class="video-container">
            <h2>Camera Feed</h2>
            <video id="video" autoplay playsinline></video>
        </div>
        
        <div class="video-container">
            <h2>Processed Feed with Lane Detection</h2>
            <canvas id="canvas"></canvas>
        </div>
        
        <div class="controls">
            <button id="startBtn">Start</button>
            <button id="stopBtn">Stop</button>
        </div>
        
        <div id="info" style="margin-top: 20px;"></div>
    </div>

    <script>
        const video = document.getElementById('video');
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');
        const startBtn = document.getElementById('startBtn');
        const stopBtn = document.getElementById('stopBtn');
        const info = document.getElementById('info');
        
        let stream;
        let intervalId;
        
        // Set up the canvas size
        function setupCanvas() {
            canvas.width = video.videoWidth;
            canvas.height = video.videoHeight;
        }
        
        // Start the camera
        async function startCamera() {
            try {
                stream = await navigator.mediaDevices.getUserMedia({ 
                    video: { 
                        facingMode: 'environment',
                        width: { ideal: 640 },
                        height: { ideal: 480 }
                    } 
                });
                video.srcObject = stream;
                
                video.onloadedmetadata = () => {
                    setupCanvas();
                    startProcessing();
                };
                
                info.textContent = 'Camera started';
            } catch (err) {
                console.error('Error accessing camera:', err);
                info.textContent = 'Error accessing camera: ' + err.message;
            }
        }
        
        // Stop the camera
        function stopCamera() {
            if (stream) {
                stream.getTracks().forEach(track => track.stop());
                video.srcObject = null;
            }
            
            if (intervalId) {
                clearInterval(intervalId);
                intervalId = null;
            }
            
            info.textContent = 'Camera stopped';
        }
        
        // Process the video frame
        function processFrame() {
            if (video.readyState === video.HAVE_ENOUGH_DATA) {
                // Draw the video frame to the canvas
                ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
                
                // Get the image data from the canvas
                const imageData = canvas.toDataURL('image/jpeg');
                
                // Send the image data to the server for processing
                fetch('/process_frame', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ image: imageData })
                })
                .then(response => response.json())
                .then(data => {
                    if (data.error) {
                        console.error('Error processing frame:', data.error);
                        return;
                    }
                    
                    // Display the processed image
                    const img = new Image();
                    img.onload = () => {
                        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                    };
                    img.src = data.image;
                    
                    // Display lane info
                    if (data.lanes) {
                        const laneInfo = data.lanes;
                        if (laneInfo.deviation !== undefined) {
                            const direction = laneInfo.deviation < 0 ? 'left' : 'right';
                            info.textContent = `Vehicle is ${Math.abs(laneInfo.deviation).toFixed(3)}m ${direction} of center`;
                        }
                    }
                })
                .catch(err => {
                    console.error('Error sending frame to server:', err);
                });
            }
        }
        
        // Start processing frames
        function startProcessing() {
            if (!intervalId) {
                intervalId = setInterval(processFrame, 100);  // Process 10 frames per second
            }
        }
        
        // Event listeners
        startBtn.addEventListener('click', startCamera);
        stopBtn.addEventListener('click', stopCamera);
    </script>
</body>
</html>
        ''')

if __name__ == '__main__':
    # Get port from environment variable (for Render deployment)
    port = int(os.environ.get('PORT', 8080))
    
    # Start the Flask app
    print(f"Starting DriveAI Lane Detection Web Server on port {port}...")
    app.run(host='0.0.0.0', port=port, debug=False)
