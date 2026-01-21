<h1>TB-Garage</h1>

### 🚗 TB-Garage | Advanced FiveM Garage System
A high-performance, feature-rich garage and vehicle management system built for FiveM. This script provides a seamless experience for players to store, retrieve, and manage their vehicles across ESX and QBCore frameworks.

### ⚡ Overview
TB-Garage is designed with optimization and user experience in mind. It offers a clean UI, support for multiple vehicle types (cars, boats, aircraft), and a robust administrative suite. Whether you are running a serious RP server or a casual freeroam environment, this script provides the stability you need.

### 📸 Preview
![Image](https://github.com/user-attachments/assets/0ee71b36-98b6-4585-a655-496fc3d2c4cb)

### ✨ Key Features
🏦 Diverse Garage Types
Public Garages: Easily store and retrieve personal vehicles with support for different vehicle classes (land, sea, and air).

Job Garages: Dedicated storage for police, EMS, and other whitelisted jobs with grade-based vehicle access.

Private Garages: Allow players to have their own personal garage locations tied specifically to their identifier.

### 🚔 Integrated Impound System
Police Interaction: Authorized jobs can impound vehicles with custom reasons, fines, and release timers.

Player Retrieval: Players can view their impounded vehicles, see the reason for seizure, and pay fines to release them back to a public garage.

### 🔑 Vehicle Security & Remote
Lock System: Toggle vehicle locks using a hotkey (Default: U) with custom animations and light/horn effects.

Key Fob (Remote): An interactive NUI remote to start/stop engines, toggle locks, and open trunks from a distance.

### 🛠️ Developer & Admin Tools
Framework Agnostic: Auto-detects ESX or QBCore.

Admin Commands: Easily give vehicles to players or delete them from the database directly in-game.

Optimized: Low MS usage with a smart "sleep" logic for markers and interactions.

### 🚀 Installation
Download: Clone or download this repository.

Database: Import the provided SQL structure into your database.

Configuration: Adjust config.lua to match your server's needs (Framework, Impound prices, Garage locations).

Start: Add ensure tb_garage to your server.cfg.
```
ensure tb_garage
```

### 📋 Requirements
``ox_lib``(For notifications and advanced UI elements)

``oxmysql`` (For database management)

``es_extended OR qb-core``
