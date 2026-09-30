# Manual Test Checklist for AI Integration

Due to constraints in the agent environment, testing could not be fully automated. Please follow this checklist to manually verify the complete AI integration flow.

## 1. Setup & Starting Services

### A. Start FastAPI AI Service
1. Open a new terminal.
2. Navigate to the AI service: `cd services/ai-service`
3. Activate python virtual env if applicable.
4. Run the service: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload`

### B. Start Node.js Backend Gateway
1. Open a new terminal.
2. Navigate to the backend: `cd services/backend`
3. Ensure dependencies are installed: `npm install`
4. Run the backend: `npm start`
*(It should start on port 5000 and log "Kabadiwala backend running on port 5000")*

### C. Start Flutter Collector
1. Open a new terminal.
2. Navigate to the collector app: `cd apps/collector`
3. Run the app, providing the backend URL (using Android loopback by default):
   `flutter run --dart-define=BACKEND_URL=http://10.0.2.2:5000`

---

## 2. Health Verification

### D. Verify Node Health
1. In a browser or via `curl`: `http://localhost:5000/health`
2. Expected response: `{"success":true,"service":"kabadiwala-backend","message":"Backend is running"}`

### E. Verify FastAPI Health
1. In a browser or via `curl`: `http://localhost:8000/api/v1/health` (assuming standard health route exists) or verify the terminal logs indicate it is listening.

---

## 3. Node AI Endpoint Verification

### F. Send a test image through the Node AI endpoint
Use `curl` or Postman to test the backend gateway:
```bash
curl -X POST http://localhost:5000/api/ai/analyze \
  -H "Content-Type: multipart/form-data" \
  -F "file=@/path/to/test/image.jpg"
```

### G. Verify returned material and confidence
Verify the output matches the expected FastAPI output shape (e.g. `{"material": "pcb", "confidence": 0.92, ...}`).

---

## 4. End-to-End Flutter Verification

### H. Verify the Flutter Collector Flow
1. Open the Flutter app.
2. Navigate to the "Create Lot" screen.
3. Select an image using the camera/gallery workflow.
4. Observe the UI loading state ("Analyzing AI...").
5. Verify the AI suggestion correctly updates the dropdown (e.g., changes to "Motherboard / PCB").

### I. Test a PCB image
1. Provide a clear image of a PCB.
2. Record expected result: `pcb_motherboard`
3. Record actual result: [ ] (Check if UI updates to Motherboard / PCB)

### J. Test an image from another supported class
1. Provide a clear image of a battery or cable.
2. Record expected result: `battery` or `copper_wire`
3. Record actual result: [ ]

### K. Test an invalid/non-image file
1. (Via curl) Send a text file disguised as an image to the Node.js endpoint.
2. Verify a graceful failure (e.g. `400 Bad Request`).
3. (Via Flutter) Verify the UI handles the failure cleanly without crashing.

### L. Test AI service unavailable
1. Stop the Python FastAPI server (`Ctrl+C`).
2. Attempt to upload an image via the Flutter app.
3. Verify that the Node.js server returns a `500` or `504` error and the Flutter app degrades gracefully, allowing the user to select the category manually.

### M. Record Results
- [ ] Node -> FastAPI proxy successful
- [ ] Flutter -> Node integration successful
- [ ] PCB classification accurate
- [ ] Battery/Cable classification accurate
- [ ] Invalid image handled cleanly
- [ ] FastAPI downtime handled cleanly
