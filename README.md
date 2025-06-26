# 🎯 Job Scheduling Visualiser

A powerful **Branch and Bound-based Job Assignment Solver** with a **visual, interactive frontend built in Flutter** and a **Flask-powered backend**. This tool not only solves the classic **assignment problem** but also visually explains the state-space search tree, making it a great tool for **learning, teaching, and debugging**.

---

## 📌 Features

- 🔢 **Solve the Assignment Problem** using Branch & Bound
- 🌳 **Visualize the State-Space Tree** with optimal path highlighting
- 🧠 **Step-by-step exploration** with cost, bound, pruning, and optimal path decisions
- 🖥️ **Frontend in Flutter** (with GraphView for tree rendering)
- 🔙 **Backend in Python (Flask)** with API for computation
- 📱 Responsive UI designed for clarity and usability

---

## 🖼️ Demo

<img src="https://github.com/adityakv1/job_schedulingvisualiser/assets/your-screenshot.png" width="700"/>

> Shows job assignment tree generation and cost/bound decisions.

---

## 🚀 Getting Started

### 🧩 Backend (Flask)

#### ✅ Prerequisites
- Python 3.x
- pip

#### 🔧 Setup & Run
```bash
cd backend/
python -m venv venv
venv\Scripts\activate   # On Windows
pip install -r requirements.txt
python app.py
